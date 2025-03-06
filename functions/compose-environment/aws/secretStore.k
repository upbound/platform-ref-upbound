import models.io.upbound.aws.iam.v1beta1 as iamv1beta1
import models.io.upbound.aws.secretsmanager.v1beta1 as secretsmanagerv1beta1
import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

schema AWSSecretStoreInput:
    accountId: str
    deletionPolicy: str
    envName: str
    namePrefix: str
    ocds: any
    region: str
    rootCtp: str
    secretsManagerSecretArn?: str


getSecretStoreItems = lambda awsParams: AWSSecretStoreInput -> [any] {[
    ### Needed until SharedSecretStore supports IAM Roles ###
    iamv1beta1.User {
        metadata = _metadata("iamUserSecretRead") | {
            name = "{}-secrets-read".format(awsParams.namePrefix)
        }
        spec = {
            deletionPolicy = awsParams.deletionPolicy
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
            deletionPolicy = awsParams.deletionPolicy
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
            deletionPolicy = awsParams.deletionPolicy
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
            deletionPolicy = awsParams.deletionPolicy
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
            deletionPolicy = awsParams.deletionPolicy
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
            deletionPolicy = awsParams.deletionPolicy
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
    secretsmanagerv1beta1.Secret {
        metadata = _metadata("secretsmanagerSecret") | {
            name = "{}-secretsmanager-secret".format(awsParams.namePrefix)
            annotations = {
                if awsParams.secretsManagerSecretArn:
                    'crossplane.io/external-name' = awsParams.secretsManagerSecretArn
            }
        }
        spec = {
            deletionPolicy = awsParams.deletionPolicy
            forProvider = {
                name = "{}-config".format(awsParams.namePrefix)
                region = awsParams.region
                if deletionPolicy == "Delete":
                    forceOverwriteReplicaSecret = True
            }
            providerConfigRef = {
                name = awsParams.envName
            }
        }
    }
]}
