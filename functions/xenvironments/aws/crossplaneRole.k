"""
AWS IAM Role Configuration Module

This module handles the creation of IAM resources needed for Crossplane to connect
to and manage AWS services. It creates:

1. An admin role with appropriate permissions
2. Role policy attachments for necessary access
3. OIDC provider configuration for federated authentication between Upbound and AWS
"""

import models.io.upbound.aws.iam.v1beta1 as iamv1beta1
import utils

schema AWSXPRoleInput:
    """
    Input parameters for configuring AWS IAM roles and permissions
    """
    accountId: str         # AWS account ID
    deletionPolicy: str    # Deletion policy for resources (Delete or Orphan)
    envName: str           # Environment name
    ctpName: str           # Control plane name
    namePrefix: str        # Prefix for AWS resource names
    oidcProviderArn?: str  # Optional: Existing OIDC provider ARN (if any)
    region: str            # AWS region
    upboundOrg: str        # Upbound organization name


getXPRoleItems = lambda awsParams: AWSXPRoleInput -> [any] {
    """
    Creates IAM roles and permissions required for AWS provider in Crossplane.

    This function generates:
    1. An administrator IAM role with a trust policy allowing Upbound's OIDC provider
    2. A role policy attachment granting the role administrator access
    3. An OIDC provider configuration for federated authentication

    The role is configured to trust the specific Upbound control plane's
    provider-aws service account via OIDC JWT token validation.
    """
    [
    iamv1beta1.Role {
        metadata = utils._metadata("iamAdminRole") | {
            name = "{}-admin".format(awsParams.namePrefix)
        }
        spec = {
            deletionPolicy = awsParams.deletionPolicy
            forProvider = {
                assumeRolePolicy = """{{
    "Version": "2012-10-17",
    "Statement": [
        {{
            "Effect": "Allow",
            "Principal": {{
                "Federated": "arn:aws:iam::{}:oidc-provider/proidc.upbound.io"
            }},
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {{
                "StringEquals": {{
                    "proidc.upbound.io:sub": "mcp:{}/{}:provider:provider-aws",
                    "proidc.upbound.io:aud": "sts.amazonaws.com"
                }}
            }}
        }}
    ]
}}""".format(awsParams.accountId, awsParams.upboundOrg, awsParams.ctpName)
            }
            providerConfigRef = {
                name = awsParams.envName
            }
        }
    }
    iamv1beta1.RolePolicyAttachment {
        metadata = utils._metadata("iamAdminRoleAttach") | {
            name = "{}-admin".format(awsParams.namePrefix)
        }
        spec = {
            deletionPolicy = awsParams.deletionPolicy
            forProvider = {
                roleSelector = {
                    matchControllerRef = True
                }
                policyArn = "arn:aws:iam::aws:policy/AdministratorAccess"
            }
            providerConfigRef = {
                name = awsParams.envName
            }
        }
    }
    iamv1beta1.OpenIDConnectProvider {
        metadata = utils._metadata("upboundOidcProvider") | {
            name = "{}-oidc-provider".format(awsParams.namePrefix)
            annotations = {
                if awsParams.oidcProviderArn:
                    'crossplane.io/external-name' = awsParams.oidcProviderArn
            }
        }
        spec = {
            deletionPolicy = awsParams.deletionPolicy
            forProvider = {
                clientIdList = ["sts.amazonaws.com"]
                url = "https://proidc.upbound.io"
            }
            providerConfigRef = {
                name = awsParams.envName
            }
        }
    }
]}
