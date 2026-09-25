"""SharedAWSSecret composition function.

Makes an AWS Secrets Manager secret readable from an Upbound control plane. For a
SharedAWSSecret it composes:

- the Secrets Manager secret itself, unless creation is switched off
- an IAM user, a read-only policy scoped to that secret, the attachment between them, and
  an access key - SharedSecretStore cannot assume an IAM role yet, so it needs static keys
- a copy of that access key into the environment's group, where the store can read it
- a SharedSecretStore pointing at Secrets Manager, and a SharedExternalSecret that syncs
  the secret into the environment's control plane
"""

import json

import grpc
from crossplane.function import logging, resource, response
from crossplane.function.proto.v1 import run_function_pb2 as fnv1
from crossplane.function.proto.v1 import run_function_pb2_grpc as grpcv1

from models.io.crossplane.m.kubernetes.object import v1alpha1 as objectv1alpha1
from models.io.k8s.apimachinery.pkg.apis.meta import v1 as k8s
from models.io.upbound.m.aws.iam.accesskey import v1beta1 as accesskeyv1beta1
from models.io.upbound.m.aws.iam.policy import v1beta1 as policyv1beta1
from models.io.upbound.m.aws.iam.user import v1beta1 as userv1beta1
from models.io.upbound.m.aws.iam.userpolicyattachment import v1beta1 as upav1beta1
from models.io.upbound.m.aws.secretsmanager.secret import v1beta1 as smsecretv1beta1
from models.io.upbound.sa.sharedawssecret import v1 as sasv1

ORPHAN = ["Create", "Observe", "Update", "LateInitialize"]
IAM_NAME_MAX = 64


def _simple_hash(s: str) -> str:
    """Position-weighted character sum, truncated to 8 digits.

    Not a cryptographic hash, and it does not need to be: it only has to be stable, because
    its output becomes part of an AWS resource name. It must stay identical to the KCL
    original it replaces - a different value renames, and so replaces, the IAM user.
    """
    return str(abs(len(s) * 31 + sum(ord(c) * (i + 1) for i, c in enumerate(s))))[:8]


def truncate_iam_name(name: str, suffix: str) -> str:
    """Fit an IAM name into 64 characters, keeping the suffix and hashing the prefix."""
    if len(name) <= IAM_NAME_MAX:
        return name
    base = name[: len(name) - len(suffix)]
    prefix_space = IAM_NAME_MAX - len(suffix) - 8 - 1
    if prefix_space <= 0:
        return f"{_simple_hash(base)}{suffix}"
    return f"{base[:prefix_space].rstrip('-')}-{_simple_hash(base)}{suffix}"


def _dig(d: dict, *path):
    """Walk nested dicts, returning None at the first missing or empty level."""
    for key in path:
        if not isinstance(d, dict):
            return None
        d = d.get(key)
    return d


# Defaults the KCL implementation emitted without setting them - its typed models
# materialise every schema default into the output. They are the provider's and
# External Secrets Operator's own defaults, so they change nothing on a cluster, but they are
# part of the rendered desired state, and the port keeps that output identical.
OBJECT_DEFAULTS = {"deletionPropagationPolicy": "Background"}
REMOTE_REF_DEFAULTS = {"conversionStrategy": "Default", "decodingStrategy": "None", "metadataPolicy": "None"}
TARGET_DEFAULTS = {"creationPolicy": "Owner", "deletionPolicy": "Retain"}
TEMPLATE_DEFAULTS = {"engineVersion": "v2", "mergePolicy": "Replace"}


def _with_defaults(d: dict, defaults: dict) -> dict:
    """Fill in defaults under the caller's values: anything explicitly set wins."""
    return {**defaults, **d}


def _object_spec(**kwargs) -> objectv1alpha1.Spec:
    """An Object spec carrying the two provider-kubernetes defaults KCL materialised."""
    kwargs["forProvider"] = objectv1alpha1.ForProvider(**OBJECT_DEFAULTS, **kwargs["forProvider"])
    return objectv1alpha1.Spec(watch=False, **kwargs)


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

        raw = resource.struct_to_dict(req.observed.composite.resource)
        xr = sasv1.SharedAWSSecret(**raw)
        params = xr.spec.parameters
        aws = params.aws
        sms = aws.secretsManagerSecret or sasv1.SecretsManagerSecret()

        deletion_policy = params.deletionPolicy or "Orphan"
        mgmt = ["*"] if deletion_policy == "Delete" else ORPHAN
        # Opt-out, not opt-in: only an explicit false disables creation. The block itself is
        # optional, and Environment omits it whenever sharedSecret carries no settings.
        create_secret = sms.create is not False

        group = params.upbound.group
        ctp = params.upbound.controlPlane
        aws_secret_name = sms.name or f"{aws.namePrefix}-config"
        aws_pc = {"kind": "ProviderConfig", "name": aws.providerConfigRef.name}
        upbound_pc = {"kind": "ProviderConfig", "name": params.upbound.providerConfigRef.name}
        iam_name = truncate_iam_name(f"{xr.metadata.name}-{aws_secret_name}-secrets-read", "-secrets-read")
        key_secret_name = f"{group}-secrets-read-access-key"

        # User-supplied pass-through values come from the raw request, not the typed model,
        # so they reach the manifest exactly as written - no defaults added, nothing reordered.
        raw_ext = _dig(raw, "spec", "parameters", "externalSecret") or {}
        secret_labels = _dig(raw_ext, "spec", "target", "template", "metadata", "labels") or {}
        secret_template_data = _dig(raw_ext, "spec", "target", "template", "data")
        secret_data = _dig(raw_ext, "spec", "data")
        secret_namespace = raw_ext.get("namespace") or "default"
        external_secret_name = raw_ext.get("name") or ctp

        # --- IAM user workaround: needed until SharedSecretStore supports IAM roles ---
        resource.update(
            rsp.desired.resources["iamUserSecretRead"],
            userv1beta1.User(
                metadata=k8s.ObjectMeta(name=iam_name),
                spec=userv1beta1.Spec(
                    managementPolicies=mgmt,
                    forProvider=userv1beta1.ForProvider(),
                    providerConfigRef=aws_pc,
                ),
            ),
        )
        resource.update(
            rsp.desired.resources["iamPolicySecretRead"],
            policyv1beta1.Policy(
                metadata=k8s.ObjectMeta(name=iam_name),
                spec=policyv1beta1.Spec(
                    managementPolicies=mgmt,
                    forProvider=policyv1beta1.ForProvider(
                        policy=json.dumps({
                            "Version": "2012-10-17",
                            "Statement": [{
                                "Effect": "Allow",
                                "Action": [
                                    "secretsmanager:GetSecretValue",
                                    "secretsmanager:DescribeSecret",
                                    "secretsmanager:ListSecretVersionIds",
                                ],
                                "Resource": [
                                    f"arn:aws:secretsmanager:{aws.region}:{aws.accountId}:secret:{aws_secret_name}-*",
                                ],
                            }],
                        }),
                    ),
                    providerConfigRef=aws_pc,
                ),
            ),
        )
        resource.update(
            rsp.desired.resources["iamPolicySecretReadAttach"],
            upav1beta1.UserPolicyAttachment(
                metadata=k8s.ObjectMeta(name=iam_name),
                spec=upav1beta1.Spec(
                    managementPolicies=mgmt,
                    forProvider=upav1beta1.ForProvider(
                        policyArnSelector=upav1beta1.PolicyArnSelector(matchControllerRef=True),
                        userSelector=upav1beta1.UserSelector(matchControllerRef=True),
                    ),
                    providerConfigRef=aws_pc,
                ),
            ),
        )
        resource.update(
            rsp.desired.resources["iamUserAccessKey"],
            accesskeyv1beta1.AccessKey(
                metadata=k8s.ObjectMeta(name=iam_name),
                spec=accesskeyv1beta1.Spec(
                    managementPolicies=mgmt,
                    forProvider=accesskeyv1beta1.ForProvider(
                        userSelector=accesskeyv1beta1.UserSelector(matchControllerRef=True),
                    ),
                    providerConfigRef=aws_pc,
                    writeConnectionSecretToRef=accesskeyv1beta1.WriteConnectionSecretToRef(
                        name=key_secret_name,
                    ),
                ),
            ),
        )
        # Copy the access key's connection secret into the environment's group.
        resource.update(
            rsp.desired.resources["envIamUserKeySecret"],
            objectv1alpha1.Object(
                metadata=k8s.ObjectMeta(name=key_secret_name),
                spec=_object_spec(
                    managementPolicies=mgmt,
                    forProvider=dict(manifest={
                        "apiVersion": "v1",
                        "kind": "Secret",
                        "metadata": {"name": key_secret_name, "namespace": group},
                    }),
                    providerConfigRef=upbound_pc,
                    references=[objectv1alpha1.Reference(
                        patchesFrom=objectv1alpha1.PatchesFrom(
                            apiVersion="v1",
                            kind="Secret",
                            name=key_secret_name,
                            # AccessKey writes its connection secret into its own namespace -
                            # v2 dropped writeConnectionSecretToRef.namespace - which is the
                            # XR's namespace, so that is where the copy reads it from.
                            namespace=xr.metadata.namespace,
                            fieldPath="data",
                        ),
                        toFieldPath="data",
                    )],
                ),
            ),
        )

        if create_secret:
            for_provider = smsecretv1beta1.ForProvider(name=aws_secret_name, region=aws.region)
            # `is not None`, not truthiness: 0 - delete immediately, no recovery window - is
            # the value that matters, and it is falsy.
            if sms.recoveryWindowInDays is not None:
                for_provider.recoveryWindowInDays = sms.recoveryWindowInDays
            if deletion_policy == "Delete":
                for_provider.forceOverwriteReplicaSecret = True
            # Keyed by its name, not "secretsmanagerSecret": the KCL version meant to use that
            # key, but merging annotations over its metadata replaced the annotation that
            # carried it, and function-kcl then fell back to the resource name. Changing a
            # composition key makes Crossplane delete the old resource and create a new one -
            # for a Secrets Manager secret under deletionPolicy: Delete, that deletes the
            # secret's contents - so the key the KCL version actually used is the one kept.
            secret_key = f"{aws_secret_name}-secretsmanager-secret"
            resource.update(
                rsp.desired.resources[secret_key],
                smsecretv1beta1.Secret(
                    metadata=k8s.ObjectMeta(
                        name=f"{aws_secret_name}-secretsmanager-secret",
                        annotations={"crossplane.io/external-name": sms.arn} if sms.arn else {},
                    ),
                    spec=smsecretv1beta1.Spec(
                        managementPolicies=mgmt,
                        forProvider=for_provider,
                        providerConfigRef=aws_pc,
                    ),
                ),
            )

        # Secret store backed by Secrets Manager, readable from the environment's control plane.
        resource.update(
            rsp.desired.resources["sharedSecretsStore"],
            objectv1alpha1.Object(
                metadata=k8s.ObjectMeta(name=f"{ctp}-sss"),
                spec=_object_spec(
                    managementPolicies=mgmt,
                    forProvider=dict(manifest={
                        "apiVersion": "spaces.upbound.io/v1alpha1",
                        "kind": "SharedSecretStore",
                        "metadata": {"name": ctp, "namespace": group},
                        "spec": {
                            "controlPlaneSelector": {"names": [ctp]},
                            "namespaceSelector": {"names": [secret_namespace]},
                            "provider": {"aws": {
                                "service": "SecretsManager",
                                "region": aws.region,
                                "auth": {"secretRef": {
                                    "accessKeyIDSecretRef": {"name": key_secret_name, "key": "username"},
                                    "secretAccessKeySecretRef": {"name": key_secret_name, "key": "password"},
                                }},
                            }},
                        },
                    }),
                    providerConfigRef=upbound_pc,
                ),
            ),
        )

        # External secret that syncs the secret into the environment's control plane.
        template = _with_defaults(
            {"metadata": {"labels": secret_labels} if secret_labels else {}}, TEMPLATE_DEFAULTS
        )
        if secret_template_data is not None:
            template["data"] = secret_template_data
        external_secret_spec = {
            "refreshInterval": "1m",
            "secretStoreRef": {"name": ctp, "kind": "ClusterSecretStore"},
            "target": _with_defaults({"name": external_secret_name, "template": template}, TARGET_DEFAULTS),
        }
        if secret_data is not None:
            external_secret_spec["data"] = [
                {**item, "remoteRef": _with_defaults(item["remoteRef"], REMOTE_REF_DEFAULTS)}
                for item in secret_data
            ]
        else:
            external_secret_spec["dataFrom"] = [
                {"extract": _with_defaults({"key": aws_secret_name}, REMOTE_REF_DEFAULTS)}
            ]
        resource.update(
            rsp.desired.resources["sharedExternalSecret"],
            objectv1alpha1.Object(
                metadata=k8s.ObjectMeta(name=f"{ctp}-ses"),
                spec=_object_spec(
                    managementPolicies=mgmt,
                    forProvider=dict(manifest={
                        "apiVersion": "spaces.upbound.io/v1alpha1",
                        "kind": "SharedExternalSecret",
                        "metadata": {"name": external_secret_name, "namespace": group},
                        "spec": {
                            "controlPlaneSelector": {"names": [ctp]},
                            "namespaceSelector": {"names": [secret_namespace]},
                            "externalSecretSpec": external_secret_spec,
                        },
                    }),
                    providerConfigRef=upbound_pc,
                ),
            ),
        )

        log.info("Composed SharedAWSSecret", secret=aws_secret_name, create=create_secret)
        return rsp
