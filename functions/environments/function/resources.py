"""Builders for the resources an Environment composes.

Each returns a list of (composition key, resource) pairs; fn.py decides which apply. The
split mirrors the KCL modules this replaced - kubeconfigs and ProviderConfigs, the Argo CD
secret, Team and Robot, secret sync, and AWS - so a reader can hold the two side by side.

Composition keys matter beyond this file. A changed key makes Crossplane delete the resource
under the old one and create another, so every key here is the one the KCL version actually
produced - including the handful where KCL fell back to the resource's name because merging
metadata had replaced the annotation carrying the intended key. Those are marked.
"""

import base64
import json

from models.io.crossplane.m.kubernetes.object import v1alpha1 as objectv1alpha1
from models.io.crossplane.m.kubernetes.providerconfig import v1alpha1 as k8spcv1alpha1
from models.io.crossplane.protection.usage import v1beta1 as usagev1beta1
from models.io.upbound.m.aws.iam.openidconnectprovider import v1beta1 as oidcv1beta1
from models.io.upbound.m.aws.iam.role import v1beta1 as rolev1beta1
from models.io.upbound.m.aws.iam.rolepolicyattachment import v1beta1 as rpav1beta1
from models.io.upbound.m.aws.providerconfig import v1beta1 as awspcv1beta1
from models.io.upbound.m.iam.robot import v1alpha1 as robotv1alpha1
from models.io.upbound.m.iam.robotteammembership import v1alpha1 as rtmv1alpha1
from models.io.upbound.m.iam.team import v1alpha1 as teamv1alpha1
from models.io.upbound.m.iam.token import v1alpha1 as tokenv1alpha1
from models.io.upbound.m.providerconfig import v1alpha1 as upbpcv1alpha1

from .compat import kcl_str, object_spec

ORPHAN = ["Create", "Observe", "Update", "LateInitialize"]
IAM_NAME_MAX = 64
OBJECT_API = "kubernetes.m.crossplane.io/v1alpha1"

TRUST_POLICY = """{{
    "Version": "2012-10-17",
    "Statement": [
        {{
            "Effect": "Allow",
            "Principal": {{
                "Federated": "arn:aws:iam::{account_id}:oidc-provider/proidc.upbound.io"
            }},
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {{
                "StringEquals": {{
                    "proidc.upbound.io:sub": "mcp:{org}/{ctp}:provider:provider-aws",
                    "proidc.upbound.io:aud": "sts.amazonaws.com"
                }}
            }}
        }}
    ]
}}"""


def management_policies(deletion_policy: str) -> list[str]:
    """Translate the XR's Delete/Orphan parameter into managementPolicies.

    Namespaced (.m.) managed resources have no deletionPolicy; managementPolicies is the only
    way to say "do not delete the external resource".
    """
    return ["*"] if deletion_policy == "Delete" else ORPHAN


def pc_ref(name: str) -> dict:
    return {"kind": "ProviderConfig", "name": name}


def _simple_hash(s: str) -> str:
    # Must stay identical to functions/sharedawssecret: its output is part of AWS names.
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


def k8s_object(name: str | None, spec: dict, annotations: dict | None = None) -> objectv1alpha1.Object:
    metadata = {}
    if name is not None:
        metadata["name"] = name
    if annotations:
        metadata["annotations"] = annotations
    return objectv1alpha1.Object.model_validate({"metadata": metadata, "spec": object_spec(spec)})


# --- kubeconfigs and provider-kubernetes ProviderConfigs ----------------------------------


def upbound_kubeconfig(space_host: str, org: str, group: str, ctp: str) -> dict:
    """A kubeconfig for the Space (ctp == "") or for one control plane in it.

    Authenticates by running `up organization token`, which provider-kubernetes supplies
    with the Upbound token through the ProviderConfig's UpboundTokens identity.
    """
    server = (
        f"https://{space_host}"
        if ctp == ""
        else f"https://{space_host}/apis/spaces.upbound.io/v1beta1/namespaces/{group}/controlplanes/{ctp}/k8s"
    )
    return {
        "apiVersion": "v1",
        "clusters": [{"cluster": {"insecure-skip-tls-verify": True, "server": server}, "name": "upbound"}],
        "contexts": [{
            "context": {
                "cluster": "upbound",
                "extensions": [{
                    "extension": {
                        "apiVersion": "upbound.io/v1alpha1",
                        "kind": "SpaceExtension",
                        "spec": {"cloud": {"organization": org}},
                    },
                    "name": "spaces.upbound.io/space",
                }],
                "namespace": group if ctp == "" else "default",
                "user": "upbound",
            },
            "name": "upbound",
        }],
        "current-context": "upbound",
        "kind": "Config",
        "preferences": {},
        "users": [{
            "name": "upbound",
            "user": {"exec": {
                "apiVersion": "client.authentication.k8s.io/v1",
                "args": ["organization", "token"],
                "command": "up",
                "env": [{"name": "ORGANIZATION", "value": org}, {"name": "UP_PROFILE", "value": "default"}],
                "interactiveMode": "IfAvailable",
                "provideClusterInfo": False,
            }},
        }],
    }


def upbound_provider_config(*, space_host, org, provider_config_name, secret_namespace, token_ref,
                            group=None, ctp=None, prefix=None) -> list:
    """A provider-kubernetes ProviderConfig for the Space, a group, or a control plane.

    Three resources: the kubeconfig Secret (applied through an Object), the ProviderConfig
    that reads it, and a Usage that keeps the Secret until the ProviderConfig is gone.
    """
    config_name = f"{ctp}-ctp" if ctp else (f"{group}-group" if group else f"{prefix}-space")
    scope = "envCtp" if ctp else ("envGroup" if group else "space")
    secret_name = f"{config_name}-kubeconfig"
    kubeconfig = kcl_str(upbound_kubeconfig(space_host, org, group or "default", ctp or ""))
    return [
        (f"{scope}Kubeconfig", k8s_object(secret_name, {
            # The API default, set explicitly: KCL materialised it.
            "managementPolicies": ["*"],
            "forProvider": {"manifest": {
                "apiVersion": "v1",
                "kind": "Secret",
                "metadata": {"name": secret_name, "namespace": secret_namespace},
                # base64 `data`, not `stringData`: provider-kubernetes records ownership of the
                # fields it writes, and stringData is never stored, so the next observe fails.
                "data": {"kubeconfig": base64.b64encode(kubeconfig.encode()).decode()},
            }},
            "providerConfigRef": pc_ref(provider_config_name),
        })),
        # Keyed by name: see the module docstring.
        (config_name, k8spcv1alpha1.ProviderConfig.model_validate({
            "metadata": {"name": config_name},
            "spec": {
                "credentials": {
                    "source": "Secret",
                    "secretRef": {"name": secret_name, "namespace": secret_namespace, "key": "kubeconfig"},
                },
                "identity": {
                    "type": "UpboundTokens",
                    "source": "Secret",
                    "secretRef": token_ref,
                },
            },
        })),
        (f"{scope}Usage", usagev1beta1.Usage.model_validate({
            "metadata": {"name": secret_name},
            "spec": {
                "replayDeletion": True,
                "of": {"apiVersion": OBJECT_API, "kind": "Object", "resourceRef": {"name": secret_name}},
                "by": {"apiVersion": OBJECT_API, "kind": "ProviderConfig", "resourceRef": {"name": config_name}},
            },
        })),
    ]


def observe_secret(*, ctp, name, namespace, provider_config_name, resource_name) -> list:
    """An observe-only Object that reads a Secret off the bootstrap control plane."""
    return [(resource_name, k8s_object(f"{ctp}-{resource_name}-observed", {
        "managementPolicies": ["Observe"],
        "forProvider": {"manifest": {
            "apiVersion": "v1", "kind": "Secret", "metadata": {"name": name, "namespace": namespace},
        }},
        "providerConfigRef": pc_ref(provider_config_name),
    }))]


# --- Argo CD --------------------------------------------------------------------------------


def argo_server_secret(*, access_token, org, group, ctp, provider_config_name, server_ca_data, space_host) -> list:
    """Register the environment's control plane as a cluster with Argo CD."""
    cluster = f"{group}-{ctp}"
    config = {
        "execProviderConfig": {
            "apiVersion": "client.authentication.k8s.io/v1",
            "command": "up",
            "args": ["org", "token"],
            "env": {"ORGANIZATION": org, "UP_TOKEN": access_token},
        },
        "tlsClientConfig": {"insecure": False},
    }
    # KCL dropped a key whose value was Undefined; the CA is absent when the bootstrap
    # kubeconfig carries none.
    if server_ca_data is not None:
        config["tlsClientConfig"]["caData"] = server_ca_data
    b64 = lambda s: base64.b64encode(s.encode()).decode()
    return [("ctp-argocd", k8s_object(f"{ctp}-ctp-argocd-secret", {
        "managementPolicies": ["*"],
        "forProvider": {"manifest": {
            "apiVersion": "v1",
            "kind": "Secret",
            "metadata": {
                "name": cluster,
                "namespace": "argocd",
                "labels": {"argocd.argoproj.io/secret-type": "cluster"},
            },
            "type": "Opaque",
            "data": {
                "name": b64(cluster),
                "server": b64(f"https://{space_host}/apis/spaces.upbound.io/v1beta1/namespaces/{group}/controlplanes/{ctp}/k8s"),
                "config": b64(json.dumps(config)),
            },
        }},
        "providerConfigRef": pc_ref(provider_config_name),
    }))]


# --- Team and Robot -------------------------------------------------------------------------


def team_with_robot(*, group, org, token_ref, observed_team_external_name, space_provider_config_name,
                    team_name_override=None, team_external_name=None, create_group_admin_binding=False) -> list:
    """A Team, a Robot in it with a Token, and optionally admin rights for the Team on the group."""
    upbound_pc = pc_ref(f"{group}-upbound")
    team_meta = {"name": f"{group}-team"}
    if team_external_name:
        team_meta["annotations"] = {"crossplane.io/external-name": team_external_name}
    items = [
        # Keyed by name: see the module docstring.
        (f"{group}-upbound", upbpcv1alpha1.ProviderConfig.model_validate({
            "metadata": {"name": f"{group}-upbound"},
            "spec": {
                "credentials": {"secretRef": token_ref, "source": "Secret"},
                "organization": org,
            },
        })),
        ("envRobot", robotv1alpha1.Robot.model_validate({
            "metadata": {"name": f"{group}-robot"},
            "spec": {
                "managementPolicies": ["*"],
                "forProvider": {"description": f"Robot for {group}", "name": f"{group}-bot", "owner": {"name": org}},
                "providerConfigRef": upbound_pc,
            },
        })),
        ("envRobotToken", tokenv1alpha1.Token.model_validate({
            "metadata": {"name": f"{group}-robot-token"},
            "spec": {
                "managementPolicies": ["*"],
                "forProvider": {"name": group, "owner": {"idRef": {"name": f"{group}-robot"}, "type": "robots"}},
                "providerConfigRef": upbound_pc,
                "writeConnectionSecretToRef": {"name": f"{group}-robot-token"},
            },
        })),
        ("envTeam", teamv1alpha1.Team.model_validate({
            "metadata": team_meta,
            "spec": {
                "managementPolicies": ORPHAN,
                "forProvider": {"name": team_name_override or f"{group}-team", "organizationName": org},
                "providerConfigRef": upbound_pc,
            },
        })),
        ("envRobotTeamMembership", rtmv1alpha1.RobotTeamMembership.model_validate({
            "metadata": {"name": f"{group}-robot-team-membership"},
            "spec": {
                "managementPolicies": ["*"],
                "forProvider": {"robotIdRef": {"name": f"{group}-robot"}, "teamIdRef": {"name": f"{group}-team"}},
                "providerConfigRef": upbound_pc,
            },
        })),
    ]
    if create_group_admin_binding:
        subject = {"kind": "UpboundTeam", "role": "admin"}
        # The Team's Upbound ID exists only once the Team has been created; until then the
        # subject has no name and the binding cannot apply yet. KCL behaved the same way.
        if observed_team_external_name:
            subject["name"] = observed_team_external_name
        items.append(("teamAdminBinding", k8s_object(f"{group}-admin-binding", {
            "managementPolicies": ["*"],
            "forProvider": {"manifest": {
                "apiVersion": "authorization.spaces.upbound.io/v1alpha1",
                "kind": "ObjectRoleBinding",
                "metadata": {"name": f"{group}-admin-binding", "namespace": group},
                "spec": {
                    "object": {"apiGroup": "core", "resource": "namespaces", "name": group},
                    "subjects": [subject],
                },
            }},
            "providerConfigRef": pc_ref(space_provider_config_name),
        })))
    return items


# --- secret sync ----------------------------------------------------------------------------


def synced_secret(*, source_ref, dest_ref, provider_config_name) -> list:
    """Copy a Secret from the bootstrap control plane into the environment's control plane."""
    key = f"{source_ref['namespace']}-{source_ref['name']}-to-{dest_ref['namespace']}-{dest_ref['name']}-syncedSecret"
    return [(key, k8s_object(None, {
        "managementPolicies": ["*"],
        "forProvider": {"manifest": {
            "apiVersion": "v1",
            "kind": "Secret",
            "metadata": {"name": dest_ref["name"], "namespace": dest_ref["namespace"]},
        }},
        "providerConfigRef": pc_ref(provider_config_name),
        "references": [{
            "patchesFrom": {
                "apiVersion": "v1",
                "kind": "Secret",
                "name": source_ref["name"],
                "namespace": source_ref["namespace"],
                "fieldPath": "data",
            },
            "toFieldPath": "data",
        }],
    }))]


# --- AWS ------------------------------------------------------------------------------------


def aws_provider_config(*, env_name, role_arn=None, creds_secret_ref=None) -> list:
    if role_arn:
        credentials = {"source": "Upbound", "upbound": {"webIdentity": {"roleARN": role_arn}}}
    else:
        credentials = {"source": "Secret"}
        if creds_secret_ref:
            credentials["secretRef"] = creds_secret_ref
    # Keyed by name: see the module docstring.
    return [(env_name, awspcv1beta1.ProviderConfig.model_validate({
        "metadata": {"name": env_name},
        "spec": {"credentials": credentials},
    }))]


def crossplane_role(*, account_id, deletion_policy, env_name, ctp_name, name_prefix, oidc_provider_arn,
                    upbound_org) -> list:
    """An admin IAM role the environment's provider-aws assumes through Upbound's OIDC provider."""
    mgmt = management_policies(deletion_policy)
    role_name = truncate_iam_name(f"{name_prefix}-admin", "-admin")
    oidc_name = f"{name_prefix}-oidc-provider"
    return [
        ("iamAdminRole", rolev1beta1.Role.model_validate({
            "metadata": {"name": role_name},
            "spec": {
                "managementPolicies": mgmt,
                "forProvider": {
                    "assumeRolePolicy": TRUST_POLICY.format(account_id=account_id, org=upbound_org, ctp=ctp_name),
                },
                "providerConfigRef": pc_ref(env_name),
            },
        })),
        ("iamAdminRoleAttach", rpav1beta1.RolePolicyAttachment.model_validate({
            "metadata": {"name": role_name},
            "spec": {
                "managementPolicies": mgmt,
                "forProvider": {
                    "roleSelector": {"matchControllerRef": True},
                    "policyArn": "arn:aws:iam::aws:policy/AdministratorAccess",
                },
                "providerConfigRef": pc_ref(env_name),
            },
        })),
        # Keyed by name: see the module docstring.
        (oidc_name, oidcv1beta1.OpenIDConnectProvider.model_validate({
            "metadata": {
                "name": oidc_name,
                "annotations": {"crossplane.io/external-name": oidc_provider_arn} if oidc_provider_arn else {},
            },
            "spec": {
                # Adoption implies orphaning, whatever deletionPolicy says: AWS allows one OIDC
                # provider per URL per account, and proidc.upbound.io is shared by every Upbound
                # integration in it. Deleting an adopted one would break all of them.
                "managementPolicies": ORPHAN if oidc_provider_arn else mgmt,
                "forProvider": {"clientIdList": ["sts.amazonaws.com"], "url": "https://proidc.upbound.io"},
                "providerConfigRef": pc_ref(env_name),
            },
        })),
    ]
