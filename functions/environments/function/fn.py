"""Environment composition function.

An Environment is an Upbound group holding one control plane, wired to AWS. The function
works in two phases:

1. Initialisation. It observes the bootstrap control plane's kubeconfig Secret and parses out
   the Space host, organization, bootstrap group and bootstrap control plane, and records them
   in status.upbound. Nothing else is composed until those are known.
2. Composition. With status.upbound populated it composes the group and control plane, the
   provider-kubernetes ProviderConfigs that reach them, optional Argo CD registration, Team
   and Robot, and secret sync, plus the AWS ProviderConfig, admin IAM role and the nested
   SharedAWSSecret.

The values go through status rather than straight into the composition so that a kubeconfig
that later disappears does not take the environment's resources with it.
"""

import base64
import re

import grpc
import yaml
from crossplane.function import logging, resource, response
from crossplane.function.proto.v1 import run_function_pb2 as fnv1
from crossplane.function.proto.v1 import run_function_pb2_grpc as grpcv1

from models.io.upbound.sa.environment import v1 as envv1
from models.io.upbound.sa.sharedawssecret import v1 as sasv1

from . import resources as r

# The bootstrap kubeconfig's server URL has the shape
#   https://<spaceHost>/apis/spaces.upbound.io/v1beta1/namespaces/<group>/controlplanes/<ctp>/k8s
# and these pick it apart by path position.
SPACE_HOST_RE = re.compile(r"https:\/\/([.\w-]+)(?:\/[.\w-]+){8}")
BOOTSTRAP_GROUP_RE = re.compile(r"https:\/(?:\/[.\w-]+){5}\/([.\w-]+)(?:\/[.\w-]+){3}")
BOOTSTRAP_CTP_RE = re.compile(r"https:\/(?:\/[.\w-]+){7}\/([.\w-]+)(?:\/[.\w-]+)")


def _dig(d, *path):
    """Walk nested dicts, returning None at the first missing level."""
    for key in path:
        if not isinstance(d, dict):
            return None
        d = d.get(key)
    return d


def _observed(req: fnv1.RunFunctionRequest, key: str) -> dict:
    if key not in req.observed.resources:
        return {}
    return resource.struct_to_dict(req.observed.resources[key].resource)


def parse_bootstrap_kubeconfig(encoded: str) -> dict:
    """Extract the Space coordinates from the bootstrap control plane's kubeconfig."""
    kubeconfig = yaml.safe_load(base64.b64decode(encoded))
    cluster = (kubeconfig.get("clusters") or [{}])[0].get("cluster") or {}
    server = cluster.get("server")
    return {
        "serverCaData": cluster.get("certificate-authority-data"),
        "spaceHost": SPACE_HOST_RE.sub(r"\1", server),
        "bootstrapGroup": BOOTSTRAP_GROUP_RE.sub(r"\1", server),
        "bootstrapCtp": BOOTSTRAP_CTP_RE.sub(r"\1", server),
        "org": kubeconfig["contexts"][0]["context"]["extensions"][0]["extension"]["spec"]["cloud"]["organization"],
    }


def _external_secret_spec(spec) -> dict:
    """Carry externalSecret.spec across, field by field, as the KCL version did.

    Only these fields reach the nested XR; anything else the caller set is dropped. Truthiness
    for each optional field, again as before - an empty string or list is treated as unset.
    """
    out = {}
    if spec.data:
        items = []
        for item in spec.data:
            ref = {"key": item.remoteRef.key}
            for field in ("property", "version", "metadataPolicy", "conversionStrategy", "decodingStrategy"):
                if getattr(item.remoteRef, field):
                    ref[field] = getattr(item.remoteRef, field)
            entry = {"secretKey": item.secretKey, "remoteRef": ref}
            if item.sourceRef:
                entry["sourceRef"] = {}
                gen = item.sourceRef.generatorRef
                if gen:
                    entry["sourceRef"]["generatorRef"] = {"apiVersion": gen.apiVersion, "kind": gen.kind, "name": gen.name}
            items.append(entry)
        out["data"] = items
    if spec.target:
        out["target"] = {}
        template = spec.target.template
        if template:
            out["target"]["template"] = {}
            if template.data:
                out["target"]["template"]["data"] = dict(template.data)
            if template.metadata:
                out["target"]["template"]["metadata"] = (
                    {"labels": dict(template.metadata.labels)} if template.metadata.labels else {}
                )
    return out


class FunctionRunner(grpcv1.FunctionRunnerService):
    """A FunctionRunner handles gRPC RunFunctionRequests."""

    def __init__(self):
        """Create a new FunctionRunner."""
        self.log = logging.get_logger()

    async def RunFunction(
        self, req: fnv1.RunFunctionRequest, _: grpc.aio.ServicerContext
    ) -> fnv1.RunFunctionResponse:
        """Run the function."""
        log = self.log.bind(tag=req.meta.tag)
        rsp = response.to(req)

        xr = envv1.Environment(**resource.struct_to_dict(req.observed.composite.resource))
        name, namespace = xr.metadata.name, xr.metadata.namespace
        params = xr.spec.parameters
        up = params.upbound
        token_ref = {"name": up.tokenSecretRef.name, "namespace": up.tokenSecretRef.namespace, "key": up.tokenSecretRef.key}

        desired = []

        # =================================================================================
        # Initialisation
        # =================================================================================
        parsed = {}
        encoded = _dig(_observed(req, "observedCtpKubeconfig"), "status", "atProvider", "manifest", "data", "kubeconfig")
        if encoded:
            parsed = parse_bootstrap_kubeconfig(encoded)

        # Truthiness, not presence: a fresh XR's status.upbound is absent or empty, and every
        # one of these is a non-empty string once set.
        status_upbound = xr.status.upbound if xr.status and xr.status.upbound else None
        init_ready = bool(
            status_upbound
            and status_upbound.org
            and status_upbound.bootstrapCtp
            and status_upbound.bootstrapGroup
            and status_upbound.spaceHost
        )

        # Observe the bootstrap kubeconfig. Its readiness gates the whole XR's: until
        # status.upbound is populated this observer is the ONLY composed resource, and it is
        # ready as soon as the Secret exists - so function-auto-ready would report the
        # Environment Ready before any group, control plane or IAM resource had been created.
        desired.append(("observedCtpKubeconfig", r.k8s_object(f"{name}-bootstrap-ctp-kubeconfig-observed", {
            "forProvider": {"manifest": {
                "apiVersion": "v1",
                "kind": "Secret",
                "metadata": {
                    "name": up.initKubeconfigSecretRef.name,
                    "namespace": up.initKubeconfigSecretRef.namespace,
                },
            }},
            "providerConfigRef": r.pc_ref(up.initProviderConfigName),
            "managementPolicies": ["Observe"],
        })))
        ready = {"observedCtpKubeconfig": fnv1.READY_TRUE if init_ready else fnv1.READY_FALSE}

        # One write: resource.update() replaces nested maps rather than merging them.
        resource.update(rsp.desired.composite, {"status": {"upbound": {
            k: parsed[k] for k in ("bootstrapCtp", "bootstrapGroup", "org", "spaceHost") if parsed.get(k)
        }}})

        if init_ready:
            ready.update(self._compose(req, xr, status_upbound, parsed, token_ref, desired))

        for key, res in desired:
            resource.update(rsp.desired.resources[key], res)
        for key, value in ready.items():
            rsp.desired.resources[key].ready = value

        log.info("Composed Environment", initialised=init_ready, resources=len(desired))
        return rsp

    def _compose(self, req, xr, st, parsed, token_ref, desired) -> dict:
        """Everything after initialisation. Appends to `desired`; returns readiness overrides."""
        name, namespace = xr.metadata.name, xr.metadata.namespace
        params = xr.spec.parameters
        up = params.upbound
        mgmt = r.management_policies(params.deletionPolicy)
        bootstrap_pc = f"{st.bootstrapCtp}-ctp"

        # The group carries the namespace. The XRD is Namespaced, so team-a/prod and
        # team-b/prod are both valid, while the group - and everything named after it, the Team,
        # Robot, Argo secret and every AWS name - is org-wide.
        group = f"{st.bootstrapGroup}-{namespace}-{name}"
        aws_name_prefix = f"{st.org}-{group}-{name}"
        ready = {}

        if up.createCtp:
            desired.append(("ctp", r.k8s_object(f"{name}-ctp", {
                "readiness": {"policy": "DeriveFromObject"},
                "managementPolicies": mgmt,
                "forProvider": {"manifest": {
                    "apiVersion": "spaces.upbound.io/v1beta1",
                    "kind": "ControlPlane",
                    "metadata": {"name": name, "namespace": group},
                    "spec": {"class": "default", "crossplane": {"autoUpgrade": {"channel": "Rapid"}}},
                }},
                "providerConfigRef": r.pc_ref(f"{group}-group"),
            })))

        if up.createGroup:
            desired.append(("envGroup", r.k8s_object(group, {
                "managementPolicies": mgmt,
                "forProvider": {"manifest": {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": group}}},
                "providerConfigRef": r.pc_ref(f"{name}-space"),
            })))

        if up.createArgoSecret:
            desired += r.observe_secret(
                ctp=name,
                name=up.tokenSecretRef.name,
                namespace=up.tokenSecretRef.namespace,
                provider_config_name=bootstrap_pc,
                resource_name="observed-access-token",
            )
            token = _dig(_observed(req, "observed-access-token"), "status", "atProvider", "manifest", "data", "token")
            if token:
                desired += r.argo_server_secret(
                    access_token=base64.b64decode(token).decode(),
                    org=st.org,
                    group=group,
                    ctp=name,
                    provider_config_name=bootstrap_pc,
                    server_ca_data=parsed.get("serverCaData"),
                    space_host=st.spaceHost,
                )

        pc_common = dict(space_host=st.spaceHost, org=st.org, provider_config_name=bootstrap_pc,
                         secret_namespace=namespace, token_ref=token_ref)
        if up.createCtp:
            desired += r.upbound_provider_config(group=group, ctp=name, **pc_common)
        # Not gated on createGroup: the ControlPlane and the SharedAWSSecret both reach the
        # group through this ProviderConfig, whoever created the group.
        desired += r.upbound_provider_config(group=group, **pc_common)
        if up.createGroup:
            desired += r.upbound_provider_config(prefix=name, **pc_common)

        if up.teamWithRobot is not None:
            desired += r.team_with_robot(
                group=group,
                org=st.org,
                token_ref=token_ref,
                observed_team_external_name=_dig(
                    _observed(req, "envTeam"), "metadata", "annotations", "crossplane.io/external-name"
                ),
                space_provider_config_name=f"{name}-space",
                team_name_override=up.teamWithRobot.teamNameOverride,
                team_external_name=up.teamWithRobot.teamExternalName,
                create_group_admin_binding=up.createGroup,
            )

        for s in up.secretSync or []:
            desired += r.synced_secret(
                source_ref={"name": s.sourceRef.name, "namespace": s.sourceRef.namespace},
                dest_ref={"name": s.destRef.name, "namespace": s.destRef.namespace},
                provider_config_name=f"{name}-ctp",
            )

        # Every ProviderConfig is ready as soon as it exists: none has a Ready condition for
        # function-auto-ready to read.
        for key, res in desired:
            if res.kind == "ProviderConfig":
                ready[key] = fnv1.READY_TRUE

        aws = params.aws
        if aws is not None:
            aws_pc = r.aws_provider_config(
                env_name=group,
                role_arn=aws.roleArn,
                creds_secret_ref={
                    "namespace": aws.credsSecretRef.namespace,
                    "name": aws.credsSecretRef.name,
                    "key": "credentials",
                } if aws.credsSecretRef else None,
            )
            desired += aws_pc
            ready[aws_pc[0][0]] = fnv1.READY_TRUE

            if aws.providerRole is not None:
                desired += r.crossplane_role(
                    account_id=aws.accountId,
                    deletion_policy=params.deletionPolicy,
                    env_name=group,
                    ctp_name=name,
                    name_prefix=aws_name_prefix,
                    oidc_provider_arn=aws.providerRole.oidcProviderArn,
                    upbound_org=st.org,
                )

            if aws.sharedSecret is not None:
                desired.append(("sharedAWSSecret", self._shared_secret(xr, group, aws_name_prefix)))

        return ready

    @staticmethod
    def _shared_secret(xr, group: str, aws_name_prefix: str) -> sasv1.SharedAWSSecret:
        """The nested SharedAWSSecret XR, carrying only the settings the caller gave."""
        params = xr.spec.parameters
        aws = params.aws
        shared = aws.sharedSecret
        aws_params = {
            "accountId": aws.accountId,
            "region": aws.region,
            "namePrefix": aws_name_prefix,
            "providerConfigRef": {"name": group},
        }
        sms = shared.secretsManagerSecret
        # Presence, not content: the KCL version tested a typed schema instance, which is
        # truthy even when empty.
        if sms is not None:
            aws_params["secretsManagerSecret"] = {
                k: v for k, v in {
                    "arn": sms.arn or None,
                    "name": sms.name or None,
                    # `is not None`, not truthiness: 0 is the value that matters.
                    "recoveryWindowInDays": sms.recoveryWindowInDays,
                    "create": sms.create,
                }.items() if v is not None
            }
        spec_params = {
            "deletionPolicy": params.deletionPolicy,
            "aws": aws_params,
            "upbound": {
                "group": group,
                "controlPlane": xr.metadata.name,
                "providerConfigRef": {"name": f"{group}-group"},
            },
        }
        # Always present, even for sharedSecret: {} - same typed-instance truthiness as above.
        ext = shared.externalSecret
        # namespace is always present: KCL's typed model materialised its "default".
        external = {"namespace": (ext.namespace if ext is not None and ext.namespace else "default")}
        if ext is not None:
            if ext.name:
                external["name"] = ext.name
            if ext.spec is not None:
                external["spec"] = _external_secret_spec(ext.spec)
        spec_params["externalSecret"] = external
        return sasv1.SharedAWSSecret.model_validate({
            "metadata": {"name": f"{xr.metadata.name}-shared-secret"},
            "spec": {"parameters": spec_params},
        })
