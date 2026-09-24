import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesm
import models.io.upbound.awsm.iam.v1beta1 as iamv1beta1
import models.io.upbound.awsm.secretsmanager.v1beta1 as secretsmanagerv1beta1
import models.io.k8s.api.core.v1 as v1
import spaces.v1alpha1 as spacesv1alpha1

import json

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

# Simple hash function for string using character sum
_simpleHash = lambda s: str -> str {
    # Simple hash based on character codes (sum with weights)
    hash = len(s) * 31
    chars = [c for c in s]
    result = sum([ord(chars[i]) * (i + 1) for i in range(len(chars))])
    str(abs(hash + result))[:8]
}

# Function to truncate IAM resource names to 64 characters
# When name exceeds limit, replace prefix with hash to preserve suffix
_truncateIamName = lambda name: str, suffix: str -> str {
    maxLength = 64
    suffixLength = len(suffix)
    hashLength = 8
    separatorLength = 1
    prefixSpace = maxLength - suffixLength - hashLength - separatorLength
    baseName = name[:len(name) - suffixLength]
    hash = _simpleHash(baseName)

    name if len(name) <= maxLength else ("{}-{}{}".format(baseName[:prefixSpace].rstrip("-"), hash, suffix) if prefixSpace > 0 else "{}{}".format(hash, suffix))
}

# Extract parameters from the XR spec
deletionPolicy = oxr.spec.parameters.deletionPolicy or "Orphan"
# Namespaced (.m.) managed resources have no deletionPolicy field; managementPolicies
# is the v2 equivalent. The XR keeps the friendlier Delete/Orphan parameter.
_mgmt = ["*"] if deletionPolicy == "Delete" else ["Create", "Observe", "Update", "LateInitialize"]
accountId = oxr.spec.parameters.aws.accountId
region = oxr.spec.parameters.aws.region

secretsManagerSecretArn = oxr.spec.parameters.aws.secretsManagerSecret?.arn or Undefined
secretsManagerSecretName = oxr.spec.parameters.aws.secretsManagerSecret?.name or Undefined
# Keep the `?.` chain on every access: secretsManagerSecret is optional, and reading
# .create directly off it crashes the whole pipeline when the caller omits the block
# (which Environment does whenever sharedSecret is given without secretsManagerSecret).
# Creation is opt-out, not opt-in: only an explicit `false` disables it. Written this way
# because the block is optional and an absent one yields None rather than Undefined, so
# neither a bare `.create` (crashes) nor an `== Undefined` test (silently returns falsy,
# skipping the secret entirely) is safe here.
_smsCreate = oxr.spec.parameters.aws.secretsManagerSecret?.create
_secretsManagerSecretCreate = False if _smsCreate == False else True

groupName = oxr.spec.parameters.upbound.group
ctpName = oxr.spec.parameters.upbound.controlPlane
namePrefix = oxr.spec.parameters.aws.namePrefix
awsSecretName = secretsManagerSecretName or "{}-config".format(namePrefix)
awsProviderConfigName = oxr.spec.parameters.aws.providerConfigRef.name
upboundProviderConfigName = oxr.spec.parameters.upbound.providerConfigRef.name
secretLabels = oxr.spec.parameters.externalSecret?.spec?.target?.template?.metadata?.labels or {}
secretNamespace = oxr.spec.parameters.externalSecret?.namespace or "default"
secretData = oxr.spec.parameters.externalSecret?.spec?.data or Undefined
secretTemplateData = oxr.spec.parameters.externalSecret?.spec?.target?.template?.data or Undefined
externalSecretName = oxr.spec.parameters.externalSecret?.name or ctpName

_items = [
    ### Needed until SharedSecretStore supports IAM Roles ###
    iamv1beta1.User {
        metadata = _metadata("iamUserSecretRead") | {
            name = _truncateIamName("{}-{}-secrets-read".format(oxr.metadata.name, awsSecretName), "-secrets-read")
        }
        spec = {
            managementPolicies = _mgmt
            forProvider = {}
            providerConfigRef = {
                kind = "ProviderConfig"
                name = awsProviderConfigName
            }
        }
    }
    iamv1beta1.Policy {
        metadata = _metadata("iamPolicySecretRead") | {
            name = _truncateIamName("{}-{}-secrets-read".format(oxr.metadata.name, awsSecretName), "-secrets-read")
        }
        spec = {
            managementPolicies = _mgmt
            forProvider = {
                policy = json.encode({
                    "Version": "2012-10-17"
                    "Statement": [
                        {
                            "Effect": "Allow"
                            "Action": [
                                "secretsmanager:GetSecretValue"
                                "secretsmanager:DescribeSecret"
                                "secretsmanager:ListSecretVersionIds"
                            ]
                            "Resource": [
                                "arn:aws:secretsmanager:{}:{}:secret:{}-*".format(region, accountId, awsSecretName)
                            ]
                        }
                    ]
                })
            }
            providerConfigRef = {
                kind = "ProviderConfig"
                name = awsProviderConfigName
            }
        }
    }
    iamv1beta1.UserPolicyAttachment {
        metadata = _metadata("iamPolicySecretReadAttach") | {
            name = _truncateIamName("{}-{}-secrets-read".format(oxr.metadata.name, awsSecretName), "-secrets-read")
        }
        spec = {
            managementPolicies = _mgmt
            forProvider = {
                policyArnSelector = {
                    matchControllerRef = True
                }
                userSelector = {
                    matchControllerRef = True
                }
            }
            providerConfigRef = {
                kind = "ProviderConfig"
                name = awsProviderConfigName
            }
        }
    }
    iamv1beta1.AccessKey {
        metadata = _metadata("iamUserAccessKey") | {
            name = _truncateIamName("{}-{}-secrets-read".format(oxr.metadata.name, awsSecretName), "-secrets-read")
        }
        spec = {
            managementPolicies = _mgmt
            forProvider = {
                userSelector = {
                    matchControllerRef = True
                }
            }
            providerConfigRef = {
                kind = "ProviderConfig"
                name = awsProviderConfigName
            }
            writeConnectionSecretToRef = {
                name = "{}-secrets-read-access-key".format(groupName)
            }
        }
    }
    # copy the iam access key secret
    kubernetesm.Object{
        metadata = _metadata("envIamUserKeySecret") | {
            name = "{}-secrets-read-access-key".format(groupName)
        }
        spec = {
            managementPolicies = _mgmt
            forProvider = {
                manifest = v1.Secret{
                    metadata = {
                        name = "{}-secrets-read-access-key".format(groupName)
                        namespace = groupName
                    }
                }
            }
            providerConfigRef = {
                kind = "ProviderConfig"
                name = upboundProviderConfigName
            }
            references = [
                {
                    patchesFrom = {
                        apiVersion = "v1"
                        kind = "Secret"
                        name = "{}-secrets-read-access-key".format(groupName)
                        # The AccessKey connection secret is written into the MR's own
                        # namespace (v2 dropped writeConnectionSecretToRef.namespace),
                        # which is the XR's namespace - not the hardcoded "default".
                        namespace = oxr.metadata.namespace
                        fieldPath = "data"
                    }
                    toFieldPath = "data"
                }
            ]
        }
    }
    ### end iam user workaround ###
    if _secretsManagerSecretCreate:
        secretsmanagerv1beta1.Secret {
            metadata = _metadata("secretsmanagerSecret") | {
                name = "{}-secretsmanager-secret".format(awsSecretName)
                annotations = {
                    if secretsManagerSecretArn:
                        'crossplane.io/external-name' = secretsManagerSecretArn
                }
            }
            spec = {
                managementPolicies = _mgmt
                forProvider = {
                    name = awsSecretName
                    region = region
                    if deletionPolicy == "Delete":
                        forceOverwriteReplicaSecret = True
                }
                providerConfigRef = {
                    kind = "ProviderConfig"
                    name = awsProviderConfigName
                }
            }
        }
    # Shared secret store mapped to secret on cloud-provider
    kubernetesm.Object{
        metadata = _metadata("sharedSecretsStore") | {
            name = "{}-sss".format(ctpName)
        }
        spec = {
            managementPolicies = _mgmt
            forProvider = {
                manifest = spacesv1alpha1.SharedSecretStore{
                    metadata = {
                        name = ctpName
                        namespace = groupName
                    }
                    spec = {
                        controlPlaneSelector = {
                            names = [ctpName]
                        }
                        namespaceSelector = {
                            names = [secretNamespace]
                        }
                        provider = {
                            aws = {
                                service = "SecretsManager"
                                region = region
                                auth = {
                                    secretRef = {
                                        accessKeyIDSecretRef = {
                                            name = "{}-secrets-read-access-key".format(groupName)
                                            key = "username"
                                        }
                                        secretAccessKeySecretRef = {
                                            name = "{}-secrets-read-access-key".format(groupName)
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
                kind = "ProviderConfig"
                name = upboundProviderConfigName
            }
        }
    }

    # Shared secret which will populate initial secret from cloud into
    # the main controlplane of the environment
    kubernetesm.Object{
        metadata = _metadata("sharedExternalSecret") | {
            name = "{}-ses".format(ctpName)
        }
        spec = {
            managementPolicies = _mgmt
            forProvider = {
                manifest = spacesv1alpha1.SharedExternalSecret{
                    metadata = {
                        name = externalSecretName
                        namespace = groupName
                    }
                    spec = {
                        controlPlaneSelector = {
                            names = [ctpName]
                        }
                        namespaceSelector = {
                            names = [secretNamespace]
                        }
                        externalSecretSpec = {
                            refreshInterval = "1m"
                            secretStoreRef = {
                                name = ctpName
                                kind = "ClusterSecretStore"
                            }
                            target = {
                                name = externalSecretName
                                template = {
                                    metadata = {
                                        if secretLabels:
                                            labels = secretLabels
                                    }
                                    if secretTemplateData != Undefined:
                                        data = secretTemplateData
                                }
                            }
                            if secretData != Undefined:
                                data = secretData
                            else:
                                dataFrom = [{
                                    extract = {
                                        key = awsSecretName
                                    }
                                }]
                        }
                    }
                }
            }
            providerConfigRef = {
                kind = "ProviderConfig"
                name = upboundProviderConfigName
            }
        }
    }
]

items = _items
