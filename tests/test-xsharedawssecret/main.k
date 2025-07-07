import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
import models.io.upbound.aws.iam.v1beta1 as iamv1beta1
import models.io.upbound.aws.secretsmanager.v1beta1 as secretsmanagerv1beta1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.sa.v1 as sav1
import kube.api.core.v1 as v1
import json

# Common resources that are the same across all test scenarios (only the secret copy)
_commonResources = [
    kubernetesv1alpha2.Object{
        metadata = {
            name = "example-env-secrets-read-access-key"
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                manifest = v1.Secret{
                    metadata = {
                        name = "example-env-secrets-read-access-key"
                        namespace = "example-env"
                    }
                }
            }
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env-group"
            }
            references = [
                {
                    patchesFrom = {
                        apiVersion = "v1"
                        fieldPath = "data"
                        kind = "Secret"
                        name = "example-env-secrets-read-access-key"
                        namespace = "default"
                    }
                    toFieldPath = "data"
                }
            ]
            watch = False
        }
    }
]

# Static IAM resources for different test cases
_iamResourcesDefault = [
    iamv1beta1.Policy{
        metadata = {
            name = "example-shared-secret-example-env-config-secrets-read"
        }
        spec = {
            deletionPolicy = "Orphan"
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
                                "arn:aws:secretsmanager:us-east-1:123456789012:secret:example-env-config-*"
                            ]
                        }
                    ]
                })
            }
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
        }
    }
    iamv1beta1.UserPolicyAttachment{
        metadata = {
            name = "example-shared-secret-example-env-config-secrets-read"
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
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
        }
    }
    iamv1beta1.AccessKey{
        metadata = {
            name = "example-shared-secret-example-env-config-secrets-read"
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                userSelector = {
                    matchControllerRef = True
                }
            }
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
            writeConnectionSecretToRef = {
                name = "example-env-secrets-read-access-key"
                namespace = "default"
            }
        }
    }
    iamv1beta1.User{
        metadata = {
            name = "example-shared-secret-example-env-config-secrets-read"
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {}
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
        }
    }
]

_iamResourcesOverride = [
    iamv1beta1.Policy{
        metadata = {
            name = "example-shared-secret-example-config-secrets-read"
        }
        spec = {
            deletionPolicy = "Orphan"
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
                                "arn:aws:secretsmanager:us-east-1:123456789012:secret:example-config-*"
                            ]
                        }
                    ]
                })
            }
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
        }
    }
    iamv1beta1.UserPolicyAttachment{
        metadata = {
            name = "example-shared-secret-example-config-secrets-read"
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
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
        }
    }
    iamv1beta1.AccessKey{
        metadata = {
            name = "example-shared-secret-example-config-secrets-read"
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                userSelector = {
                    matchControllerRef = True
                }
            }
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
            writeConnectionSecretToRef = {
                name = "example-env-secrets-read-access-key"
                namespace = "default"
            }
        }
    }
    iamv1beta1.User{
        metadata = {
            name = "example-shared-secret-example-config-secrets-read"
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {}
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
        }
    }
]

_iamResourcesNoCreate = [
    iamv1beta1.Policy{
        metadata = {
            name = "example-shared-secret-existing-secret-secrets-read"
        }
        spec = {
            deletionPolicy = "Orphan"
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
                                "arn:aws:secretsmanager:us-east-1:123456789012:secret:existing-secret-*"
                            ]
                        }
                    ]
                })
            }
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
        }
    }
    iamv1beta1.UserPolicyAttachment{
        metadata = {
            name = "example-shared-secret-existing-secret-secrets-read"
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
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
        }
    }
    iamv1beta1.AccessKey{
        metadata = {
            name = "example-shared-secret-existing-secret-secrets-read"
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                userSelector = {
                    matchControllerRef = True
                }
            }
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
            writeConnectionSecretToRef = {
                name = "example-env-secrets-read-access-key"
                namespace = "default"
            }
        }
    }
    iamv1beta1.User{
        metadata = {
            name = "example-shared-secret-existing-secret-secrets-read"
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {}
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
        }
    }
]

# Static shared resources
_sharedSecretStoreDefault = kubernetesv1alpha2.Object{
    metadata = {
        name = "example-ctp-sss"
    }
    spec = {
        deletionPolicy = "Orphan"
        forProvider = {
            manifest = {
                apiVersion = "spaces.upbound.io/v1alpha1"
                kind = "SharedSecretStore"
                metadata = {
                    name = "example-ctp"
                    namespace = "example-env"
                }
                spec = {
                    controlPlaneSelector = {
                        names = ["example-ctp"]
                    }
                    namespaceSelector = {
                        names = ["default"]
                    }
                    provider = {
                        aws = {
                            auth = {
                                secretRef = {
                                    accessKeyIDSecretRef = {
                                        key = "username"
                                        name = "example-env-secrets-read-access-key"
                                    }
                                    secretAccessKeySecretRef = {
                                        key = "password"
                                        name = "example-env-secrets-read-access-key"
                                    }
                                }
                            }
                            region = "us-east-1"
                            service = "SecretsManager"
                        }
                    }
                }
            }
        }
        managementPolicies = ["*"]
        providerConfigRef = {
            name = "example-env-group"
        }
        watch = False
    }
}

_sharedSecretStoreNamespaceOverride = kubernetesv1alpha2.Object{
    metadata = {
        name = "example-ctp-sss"
    }
    spec = {
        deletionPolicy = "Orphan"
        forProvider = {
            manifest = {
                apiVersion = "spaces.upbound.io/v1alpha1"
                kind = "SharedSecretStore"
                metadata = {
                    name = "example-ctp"
                    namespace = "example-env"
                }
                spec = {
                    controlPlaneSelector = {
                        names = ["example-ctp"]
                    }
                    namespaceSelector = {
                        names = ["my-namespace"]
                    }
                    provider = {
                        aws = {
                            auth = {
                                secretRef = {
                                    accessKeyIDSecretRef = {
                                        key = "username"
                                        name = "example-env-secrets-read-access-key"
                                    }
                                    secretAccessKeySecretRef = {
                                        key = "password"
                                        name = "example-env-secrets-read-access-key"
                                    }
                                }
                            }
                            region = "us-east-1"
                            service = "SecretsManager"
                        }
                    }
                }
            }
        }
        managementPolicies = ["*"]
        providerConfigRef = {
            name = "example-env-group"
        }
        watch = False
    }
}

_sharedExternalSecretDefault = kubernetesv1alpha2.Object{
    metadata = {
        name = "example-ctp-ses"
    }
    spec = {
        deletionPolicy = "Orphan"
        forProvider = {
            manifest = {
                apiVersion = "spaces.upbound.io/v1alpha1"
                kind = "SharedExternalSecret"
                metadata = {
                    name = "example-ctp"
                    namespace = "example-env"
                }
                spec = {
                    controlPlaneSelector = {
                        names = ["example-ctp"]
                    }
                    externalSecretSpec = {
                        dataFrom = [
                            {
                                extract = {
                                    conversionStrategy = "Default"
                                    decodingStrategy = "None"
                                    key = "example-env-config"
                                    metadataPolicy = "None"
                                }
                            }
                        ]
                        refreshInterval = "1m"
                        secretStoreRef = {
                            kind = "ClusterSecretStore"
                            name = "example-ctp"
                        }
                        target = {
                            creationPolicy = "Owner"
                            deletionPolicy = "Retain"
                            name = "example-ctp"
                        }
                    }
                    namespaceSelector = {
                        names = ["default"]
                    }
                }
            }
        }
        managementPolicies = ["*"]
        providerConfigRef = {
            name = "example-env-group"
        }
        watch = False
    }
}

_sharedExternalSecretOverride = kubernetesv1alpha2.Object{
    metadata = {
        name = "example-ctp-ses"
    }
    spec = {
        deletionPolicy = "Orphan"
        forProvider = {
            manifest = {
                apiVersion = "spaces.upbound.io/v1alpha1"
                kind = "SharedExternalSecret"
                metadata = {
                    name = "example-ctp"
                    namespace = "example-env"
                }
                spec = {
                    controlPlaneSelector = {
                        names = ["example-ctp"]
                    }
                    externalSecretSpec = {
                        dataFrom = [
                            {
                                extract = {
                                    conversionStrategy = "Default"
                                    decodingStrategy = "None"
                                    key = "example-config"
                                    metadataPolicy = "None"
                                }
                            }
                        ]
                        refreshInterval = "1m"
                        secretStoreRef = {
                            kind = "ClusterSecretStore"
                            name = "example-ctp"
                        }
                        target = {
                            creationPolicy = "Owner"
                            deletionPolicy = "Retain"
                            name = "example-ctp"
                            template = {
                                metadata = {
                                    labels = {
                                        app = "my-app"
                                        environment = "production"
                                    }
                                }
                            }
                        }
                    }
                    namespaceSelector = {
                        names = ["my-namespace"]
                    }
                }
            }
        }
        managementPolicies = ["*"]
        providerConfigRef = {
            name = "example-env-group"
        }
        watch = False
    }
}

_sharedExternalSecretNoCreate = kubernetesv1alpha2.Object{
    metadata = {
        name = "example-ctp-ses"
    }
    spec = {
        deletionPolicy = "Orphan"
        forProvider = {
            manifest = {
                apiVersion = "spaces.upbound.io/v1alpha1"
                kind = "SharedExternalSecret"
                metadata = {
                    name = "example-ctp"
                    namespace = "example-env"
                }
                spec = {
                    controlPlaneSelector = {
                        names = ["example-ctp"]
                    }
                    externalSecretSpec = {
                        dataFrom = [
                            {
                                extract = {
                                    conversionStrategy = "Default"
                                    decodingStrategy = "None"
                                    key = "existing-secret"
                                    metadataPolicy = "None"
                                }
                            }
                        ]
                        refreshInterval = "1m"
                        secretStoreRef = {
                            kind = "ClusterSecretStore"
                            name = "example-ctp"
                        }
                        target = {
                            creationPolicy = "Owner"
                            deletionPolicy = "Retain"
                            name = "example-ctp"
                        }
                    }
                    namespaceSelector = {
                        names = ["default"]
                    }
                }
            }
        }
        managementPolicies = ["*"]
        providerConfigRef = {
            name = "example-env-group"
        }
        watch = False
    }
}

# Static SecretsManager Secret resources for each test case
_secretsManagerSecretDefault = secretsmanagerv1beta1.Secret{
    metadata = {
        name = "example-env-config-secretsmanager-secret"
        annotations = {
            "crossplane.io/external-name" = "arn:aws:secretsmanager:us-east-1:123456789012:secret:example-env-config-AbCdEf"
        }
    }
    spec = {
        deletionPolicy = "Orphan"
        forProvider = {
            name = "example-env-config"
            region = "us-east-1"
        }
        managementPolicies = ["*"]
        providerConfigRef = {
            name = "example-env"
        }
    }
}

_secretsManagerSecretOverride = secretsmanagerv1beta1.Secret{
    metadata = {
        name = "example-config-secretsmanager-secret"
        annotations = {
            "crossplane.io/external-name" = "arn:aws:secretsmanager:us-east-1:123456789012:secret:example-config-AbCdEf"
        }
    }
    spec = {
        deletionPolicy = "Orphan"
        forProvider = {
            name = "example-config"
            region = "us-east-1"
        }
        managementPolicies = ["*"]
        providerConfigRef = {
            name = "example-env"
        }
    }
}

# Long name resources with hashing
_iamResourcesLongName = [
    iamv1beta1.Policy{
        metadata = {
            name = "example-shared-secret-this-is-a-very-long-1046060-secrets-read"
        }
        spec = {
            deletionPolicy = "Orphan"
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
                                "arn:aws:secretsmanager:us-east-1:123456789012:secret:this-is-a-very-long-secret-name-that-will-exceed-the-64-character-limit-for-iam-resources-and-should-trigger-hash-truncation-*"
                            ]
                        }
                    ]
                })
            }
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
        }
    }
    iamv1beta1.UserPolicyAttachment{
        metadata = {
            name = "example-shared-secret-this-is-a-very-long-1046060-secrets-read"
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
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
        }
    }
    iamv1beta1.AccessKey{
        metadata = {
            name = "example-shared-secret-this-is-a-very-long-1046060-secrets-read"
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                userSelector = {
                    matchControllerRef = True
                }
            }
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
            writeConnectionSecretToRef = {
                name = "example-env-secrets-read-access-key"
                namespace = "default"
            }
        }
    }
    iamv1beta1.User{
        metadata = {
            name = "example-shared-secret-this-is-a-very-long-1046060-secrets-read"
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {}
            managementPolicies = ["*"]
            providerConfigRef = {
                name = "example-env"
            }
        }
    }
]

_secretsManagerSecretLongName = secretsmanagerv1beta1.Secret{
    metadata = {
        name = "this-is-a-very-long-secret-name-that-will-exceed-the-64-character-limit-for-iam-resources-and-should-trigger-hash-truncation-secretsmanager-secret"
        annotations = {
            "crossplane.io/composition-resource-name" = "this-is-a-very-long-secret-name-that-will-exceed-the-64-character-limit-for-iam-resources-and-should-trigger-hash-truncation-secretsmanager-secret"
        }
    }
    spec = {
        deletionPolicy = "Orphan"
        forProvider = {
            name = "this-is-a-very-long-secret-name-that-will-exceed-the-64-character-limit-for-iam-resources-and-should-trigger-hash-truncation"
            region = "us-east-1"
        }
        managementPolicies = ["*"]
        providerConfigRef = {
            name = "example-env"
        }
    }
}

_sharedExternalSecretLongName = kubernetesv1alpha2.Object{
    metadata = {
        name = "example-ctp-ses"
    }
    spec = {
        deletionPolicy = "Orphan"
        forProvider = {
            manifest = {
                apiVersion = "spaces.upbound.io/v1alpha1"
                kind = "SharedExternalSecret"
                metadata = {
                    name = "example-ctp"
                    namespace = "example-env"
                }
                spec = {
                    controlPlaneSelector = {
                        names = ["example-ctp"]
                    }
                    externalSecretSpec = {
                        dataFrom = [
                            {
                                extract = {
                                    conversionStrategy = "Default"
                                    decodingStrategy = "None"
                                    key = "this-is-a-very-long-secret-name-that-will-exceed-the-64-character-limit-for-iam-resources-and-should-trigger-hash-truncation"
                                    metadataPolicy = "None"
                                }
                            }
                        ]
                        refreshInterval = "1m"
                        secretStoreRef = {
                            kind = "ClusterSecretStore"
                            name = "example-ctp"
                        }
                        target = {
                            creationPolicy = "Owner"
                            deletionPolicy = "Retain"
                            name = "example-ctp"
                        }
                    }
                    namespaceSelector = {
                        names = ["default"]
                    }
                }
            }
        }
        managementPolicies = ["*"]
        providerConfigRef = {
            name = "example-env-group"
        }
        watch = False
    }
}

_items = [
    # Test case 1: Default behavior using namePrefix logic
    metav1alpha1.CompositionTest{
        metadata.name: "test-xsharedawssecret"
        spec= {
            assertResources: _commonResources + _iamResourcesDefault + [
                _secretsManagerSecretDefault
                _sharedSecretStoreDefault
                _sharedExternalSecretDefault
            ]
            compositionPath: "apis/xsharedawssecrets/composition.yaml"
            xrPath: "examples/xsharedawssecret/example-default.yaml"
            xrdPath: "apis/xsharedawssecrets/definition.yaml"
            timeoutSeconds: 60
            validate: False
        }
    }
    # Test case 2: With explicit secretsManagerSecret.name override
    metav1alpha1.CompositionTest{
        metadata.name: "test-xsharedawssecret-name-override"
        spec= {
            assertResources: _commonResources + _iamResourcesOverride + [
                _secretsManagerSecretOverride
                _sharedSecretStoreNamespaceOverride
                _sharedExternalSecretOverride
            ]
            compositionPath: "apis/xsharedawssecrets/composition.yaml"
            xrPath: "examples/xsharedawssecret/example.yaml"
            xrdPath: "apis/xsharedawssecrets/definition.yaml"
            timeoutSeconds: 60
            validate: False
        }
    }
    # Test case 3: With create set to false (no secret creation, but IAM resources still created)
    metav1alpha1.CompositionTest{
        metadata.name: "test-xsharedawssecret-no-create"
        spec= {
            assertResources: _commonResources + _iamResourcesNoCreate + [
                # No secretsManagerSecret in this case since create=false
                _sharedSecretStoreDefault
                _sharedExternalSecretNoCreate
            ]
            compositionPath: "apis/xsharedawssecrets/composition.yaml"
            xr: sav1.XSharedAWSSecret{
                metadata = {
                    name = "example-shared-secret"
                }
                spec = {
                    parameters = {
                        deletionPolicy = "Orphan"
                        aws = {
                            accountId = "123456789012"
                            region = "us-east-1"
                            secretsManagerSecret = {
                                name = "existing-secret"
                                create = False
                            }
                            namePrefix = "example-env"
                            providerConfigRef = {
                                name = "example-env"
                            }
                        }
                        upbound = {
                            group = "example-env"
                            controlPlane = "example-ctp"
                            providerConfigRef = {
                                name = "example-env-group"
                            }
                        }
                    }
                }
            }
            xrdPath: "apis/xsharedawssecrets/definition.yaml"
            timeoutSeconds: 60
            validate: False
        }
    }
    # Test case 4: Long name that triggers hash truncation
    metav1alpha1.CompositionTest{
        metadata.name: "test-xsharedawssecret-long-name"
        spec= {
            assertResources: _commonResources + _iamResourcesLongName + [
                _secretsManagerSecretLongName
                _sharedSecretStoreDefault
                _sharedExternalSecretLongName
            ]
            compositionPath: "apis/xsharedawssecrets/composition.yaml"
            xr: sav1.XSharedAWSSecret{
                metadata = {
                    name = "example-shared-secret"
                }
                spec = {
                    parameters = {
                        deletionPolicy = "Orphan"
                        aws = {
                            accountId = "123456789012"
                            region = "us-east-1"
                            secretsManagerSecret = {
                                name = "this-is-a-very-long-secret-name-that-will-exceed-the-64-character-limit-for-iam-resources-and-should-trigger-hash-truncation"
                                create = True
                            }
                            namePrefix = "example-env"
                            providerConfigRef = {
                                name = "example-env"
                            }
                        }
                        upbound = {
                            group = "example-env"
                            controlPlane = "example-ctp"
                            providerConfigRef = {
                                name = "example-env-group"
                            }
                        }
                    }
                }
            }
            xrdPath: "apis/xsharedawssecrets/definition.yaml"
            timeoutSeconds: 60
            validate: False
        }
    }
]
items= _items
