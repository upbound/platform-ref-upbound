import models.io.upbound.aws.iam.v1beta1 as iamv1beta1
import models.io.upbound.aws.secretsmanager.v1beta1 as secretsmanagerv1beta1
import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
import modelsSpace.v1alpha1 as spacesv1alpha1

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

schema AWSSecretStoreInput:
    accountId: str
    deletionPolicy: str
    ctpName: str
    envName: str
    namePrefix: str
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
                }
            }
            providerConfigRef = {
                name = "{}-group".format(awsParams.envName)
            }
            references = [
                {
                    patchesFrom = {
                        apiVersion = "v1"
                        kind = "Secret"
                        name = "{}-secrets-read-access-key".format(awsParams.envName)
                        namespace = "default"
                        fieldPath = "data"
                    }
                    toFieldPath = "data"
                }
            ]
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
                if awsParams.deletionPolicy == "Delete":
                    forceOverwriteReplicaSecret = True
            }
            providerConfigRef = {
                name = awsParams.envName
            }
        }
    }
    # Shared secret store mapped to secret on cloud-provider
    kubernetesv1alpha2.Object{
        metadata = _metadata("sharedSecretsStore") | {
            name = "{}-sss".format(awsParams.ctpName)
        }
        spec = {
            deletionPolicy = awsParams.deletionPolicy
            forProvider = {
                manifest = spacesv1alpha1.SharedSecretStore{
                    metadata = {
                        name = awsParams.ctpName
                        namespace = awsParams.envName
                    }
                    spec = {
                        controlPlaneSelector = {
                            names = [awsParams.ctpName]
                        }
                        namespaceSelector = {
                            names = ["default"]
                        }
                        provider = {
                            aws = {
                                service = "SecretsManager"
                                region = awsParams.region
                                auth = {
                                    secretRef = {
                                        accessKeyIDSecretRef = {
                                            name = "{}-secrets-read-access-key".format(awsParams.envName)
                                            key = "username"
                                        }
                                        secretAccessKeySecretRef = {
                                            name = "{}-secrets-read-access-key".format(awsParams.envName)
                                            key = "password"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            providerConfigRef = {
                name = "{}-group".format(awsParams.envName)
            }
        }
    }

    # Shared secret which will populate initial secret from cloud into
    # the main controlplane of the environment
    kubernetesv1alpha2.Object{
        metadata = _metadata("sharedExternalSecret") | {
            name = "{}-ses".format(awsParams.ctpName)
        }
        spec = {
            deletionPolicy = awsParams.deletionPolicy
            forProvider = {
                manifest = spacesv1alpha1.SharedExternalSecret{
                    metadata = {
                        name = awsParams.ctpName
                        namespace = awsParams.envName
                    }
                    spec = {
                        controlPlaneSelector = {
                            names = [awsParams.ctpName]
                        }
                        namespaceSelector = {
                            names = ["default"]
                        }
                        externalSecretSpec = {
                            refreshInterval = "1m"
                            secretStoreRef = {
                                name = awsParams.ctpName
                                kind = "ClusterSecretStore"
                            }
                            target = {
                                name = awsParams.ctpName
                            }
                            dataFrom = [{
                                extract = {
                                    key = "{}-config".format(awsParams.namePrefix)
                                }
                            }]
                        }
                    }
                }
            }
            providerConfigRef = {
                name = "{}-group".format(awsParams.envName)
            }
        }
    }
]}
