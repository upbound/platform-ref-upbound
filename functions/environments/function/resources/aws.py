"""The AWS ProviderConfig, and the admin IAM role provider-aws assumes through OIDC."""

from models.io.upbound.m.aws.iam.openidconnectprovider import v1beta1 as oidcv1beta1
from models.io.upbound.m.aws.iam.role import v1beta1 as rolev1beta1
from models.io.upbound.m.aws.iam.rolepolicyattachment import v1beta1 as rpav1beta1
from models.io.upbound.m.aws.providerconfig import v1beta1 as awspcv1beta1

from ..common.naming import truncate_iam_name
from ..common.policy import ORPHAN, management_policies
from .util import pc_ref

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


def aws_provider_config(*, env_name, role_arn=None, creds_secret_ref=None) -> list:
    if role_arn:
        credentials = {"source": "Upbound", "upbound": {"webIdentity": {"roleARN": role_arn}}}
    else:
        credentials = {"source": "Secret"}
        if creds_secret_ref:
            credentials["secretRef"] = creds_secret_ref
    # Keyed by name: see the resources package docstring.
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
        # Keyed by name: see the resources package docstring.
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
