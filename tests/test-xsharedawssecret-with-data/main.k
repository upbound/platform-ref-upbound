import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
import models.io.upbound.aws.iam.v1beta1 as iamv1beta1
import models.io.upbound.aws.secretsmanager.v1beta1 as secretsmanagerv1beta1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import json


_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-xsharedawssecret-with-data"
        spec= {
            assertResources: [
                # Common resources (IAM user, policy, access key, secret copy)
                kubernetesv1alpha2.Object{
                    metadata = {
                        name = "example-env-secrets-read-access-key"
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            manifest = {
                                apiVersion = "v1"
                                kind = "Secret"
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
                # IAM resources
                iamv1beta1.Policy{
                    metadata = {
                        name = "example-shared-secret-with-data-example-config-secrets-read"
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            policy = json.encode({
                                Version = "2012-10-17"
                                Statement = [
                                    {
                                        Effect = "Allow"
                                        Action = [
                                            "secretsmanager:GetSecretValue"
                                            "secretsmanager:DescribeSecret"
                                            "secretsmanager:ListSecretVersionIds"
                                        ]
                                        Resource = [
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
                        name = "example-shared-secret-with-data-example-config-secrets-read"
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
                        name = "example-shared-secret-with-data-example-config-secrets-read"
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
                        name = "example-shared-secret-with-data-example-config-secrets-read"
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
                # Secrets Manager Secret
                secretsmanagerv1beta1.Secret{
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
                # Shared Secret Store
                kubernetesv1alpha2.Object{
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
                # Shared External Secret with data (individual key mappings)
                # This is the key test: verifies that spec.data creates individual key mappings
                kubernetesv1alpha2.Object{
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
                                    name = "custom-external-secret"
                                    namespace = "example-env"
                                }
                                spec = {
                                    controlPlaneSelector = {
                                        names = ["example-ctp"]
                                    }
                                    externalSecretSpec = {
                                        # This is the key assertion: data should be used instead of dataFrom
                                        data = [
                                            {
                                                secretKey = "githubAppPrivateKey"
                                                remoteRef = {
                                                    conversionStrategy = "Default"
                                                    decodingStrategy = "None"
                                                    key = "example-config"
                                                    metadataPolicy = "None"
                                                    property = "githubAppPrivateKey"
                                                }
                                            }
                                            {
                                                secretKey = "githubCreds"
                                                remoteRef = {
                                                    conversionStrategy = "Default"
                                                    decodingStrategy = "None"
                                                    key = "example-config"
                                                    metadataPolicy = "None"
                                                    property = "githubCreds"
                                                }
                                            }
                                            {
                                                secretKey = "databaseUrl"
                                                remoteRef = {
                                                    conversionStrategy = "Default"
                                                    decodingStrategy = "Base64"
                                                    key = "example-config"
                                                    metadataPolicy = "None"
                                                    property = "databaseUrl"
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
                                            name = "custom-external-secret"
                                            template = {
                                                data = {
                                                    githubAppID = "{{ $creds := .githubCreds | fromJson }}{{ index $creds.app_auth 0 \"id\" }}"
                                                    githubInstallationID = "{{ $creds := .githubCreds | fromJson }}{{ index $creds.app_auth 0 \"installation_id\" }}"
                                                    githubPrivateKey = "{{ $creds := .githubCreds | fromJson }}{{ index $creds.app_auth 0 \"pem_file\" | replace \"\\\\n\" \"\\n\" }}"
                                                    type = "git"
                                                    url = "{{ $creds := .githubCreds | fromJson }}https://github.com/{{ $creds.owner }}"
                                                }
                                                engineVersion = "v2"
                                                mergePolicy = "Replace"
                                                metadata = {
                                                    labels = {
                                                        app = "my-app"
                                                        "argocd.argoproj.io/secret-type" = "repo-creds"
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
            ]
            compositionPath: "apis/xsharedawssecrets/composition.yaml"
            xrPath: "examples/xsharedawssecret/example-with-data.yaml"
            xrdPath: "apis/xsharedawssecrets/definition.yaml"
            timeoutSeconds: 60
            validate: False
        }
    }
]
items= _items
