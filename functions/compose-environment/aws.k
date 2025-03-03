import models.io.upbound.aws.v1beta1 as awsv1beta1
import models.io.upbound.aws.iam.v1beta1 as iamv1beta1
import models.io.upbound.aws.secretsmanager.v1beta1 as secretsmanagerv1beta1
import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

schema AWSInput:
    accountId: str
    awsCredsSecretRef: awsv1beta1.AwsUpboundIoV1beta1ProviderConfigSpecCredentialsSecretRef
    namePrefix: str
    region: str
    envName: str
    upboundOrg: str
    rootCtp: str
    ocds: any
    oidcProviderArn?: str
    secretsManagerSecretArn?: str


getItems = lambda awsParams: AWSInput -> [any] {[
    awsv1beta1.ProviderConfig{
        metadata = _metadata("awsProviderConfig") | {
            name = awsParams.envName
            annotations = {
              "krm.kcl.dev/ready" = "True"
            }
        }
        spec = {
            credentials = {
                source = "Secret"
                secretRef = awsParams.awsCredsSecretRef
            }
        }
    }
    ### Needed until SharedSecretStore supports IAM Roles ###
    iamv1beta1.User {
        metadata = _metadata("iamUserSecretRead") | {
            name = "{}-secrets-read".format(awsParams.namePrefix)
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {}
            providerConfigRef = {
                name = awsParams.envName
            }
        }
    }
    iamv1beta1.Policy {
        metadata = _metadata("iamPolicySecretRead") | {
            name = "{}-secrets-read".format(awsParams.namePrefix)
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                policy = """{{
    "Version": "2012-10-17",
    "Statement": [
        {{
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:ListSecretVersionIds"
            ],
            "Resource": [
                "arn:aws:secretsmanager:{}:{}:secret:{}-*"
            ]
        }}
    ]
}}""".format(awsParams.region, awsParams.accountId, awsParams.namePrefix)
            }
            providerConfigRef = {
                name = awsParams.envName
            }
        }
    }
    iamv1beta1.UserPolicyAttachment {
        metadata = _metadata("iamPolicySecretReadAttach") | {
            name = "{}-secrets-read".format(awsParams.namePrefix)
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                policyArnSelector = {
                    matchControllerRef = True
                }
                userSelector = {
                    matchControllerRef = True
                }
            }
            providerConfigRef = {
                name = awsParams.envName
            }
        }
    }
    iamv1beta1.AccessKey {
        metadata = _metadata("iamUserAccessKey") | {
            name = "{}-secrets-read".format(awsParams.namePrefix)
        }
        spec = {
            forProvider = {
                userSelector = {
                    matchControllerRef = True
                }
            }
            providerConfigRef = {
                name = awsParams.envName
            }
            writeConnectionSecretToRef = {
                name = "{}-secrets-read-access-key".format(awsParams.envName)
                namespace = "default"
            }
        }
    }
    # observe secret in order to copy it to environment
    kubernetesv1alpha2.Object{
        metadata = _metadata("observedIamUserKeySecret") | {
            name = "{}-secrets-read-access-key-observed".format(awsParams.envName)
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Secret"
                    metadata = {
                        name = "{}-secrets-read-access-key".format(awsParams.envName)
                        namespace = "default"
                    }
                }
            }
            providerConfigRef = {
                name = "{}-ctp".format(awsParams.rootCtp)
            }
            managementPolicies = ["Observe"]
        }
    }
    # copy the iam access key secret
    kubernetesv1alpha2.Object{
        metadata = _metadata("envIamUserKeySecret") | {
            name = "{}-secrets-read-access-key".format(awsParams.envName)
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Secret"
                    metadata = {
                        name = "{}-secrets-read-access-key".format(awsParams.envName)
                        namespace = awsParams.envName
                    }
                    data = awsParams.ocds.observedIamUserKeySecret?.Resource?.status?.atProvider?.manifest?.data
                }
            }
            providerConfigRef = {
                name = "{}-group".format(awsParams.envName)
            }
        }
    }
    ### end iam user workaroung ###

    iamv1beta1.Role {
        metadata = _metadata("iamAdminRole") | {
            name = "{}-admin".format(awsParams.namePrefix)
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                assumeRolePolicy = """{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam:::oidc-provider/proidc.upbound.io"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "proidc.upbound.io:sub": "mcp:upboundcare/solutions-non-prod-example:provider:provider-aws",
                    "proidc.upbound.io:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}"""
            }
            providerConfigRef = {
                name = awsParams.envName
            }
        }
    }
    iamv1beta1.RolePolicyAttachment {
        metadata = _metadata("iamAdminRoleAttach") | {
            name = "{}-admin".format(awsParams.namePrefix)
        }
        spec = {
            deletionPolicy = "Orphan"
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
        metadata = _metadata("upboundOidcProvider") | {
            name = "{}-oidc-provider".format(awsParams.namePrefix)
            annotations = {
                if awsParams.oidcProviderArn:
                    'crossplane.io/external-name' = awsParams.oidcProviderArn
            }
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                clientIdList = ["sts.amazonaws.com"]
                url = "https://proidc.upbound.io"
            }
            providerConfigRef = {
                name = awsParams.envName
            }
        }
    }
    secretsmanagerv1beta1.Secret {
        metadata = _metadata("secretsmanagerSecret") | {
            name = "{}-secretsmanager-secret".format(awsParams.namePrefix)
            annotations = {
                if awsParams.secretsManagerSecretArn:
                    'crossplane.io/external-name' = awsParams.secretsManagerSecretArn
            }
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                name = "{}-config".format(awsParams.namePrefix)
                region = awsParams.region
            }
            providerConfigRef = {
                name = awsParams.envName
            }
        }
    }
]}
