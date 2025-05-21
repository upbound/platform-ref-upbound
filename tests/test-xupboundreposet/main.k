import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.sa.v1 as sav1

_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-xupboundreposet"
        spec= {
            assertResources: [
                sav1.XUpboundRepoSet{
                    metadata = {
                        name = "example"
                    }
                    spec = {
                        parameters = {}
                    }
                }
                {
                    apiVersion = "upbound.io/v1alpha1"
                    kind = "ProviderConfig"
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "providerConfigUpbound"
                        }
                        generateName = "example-"
                        labels = {
                            "crossplane.io/composite" = "example"
                        }
                        name = "example-upboundcare-reposet"
                    }
                    spec = {
                        credentials = {
                            secretRef = {
                                key = "token"
                                name = "solutions-non-prod-bootstrap-token"
                                namespace = "default"
                            }
                            source = "Secret"
                        }
                        organization = "upboundcare"
                    }
                }
                {
                    apiVersion = "repository.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata = {
                        annotations = {
                            "crosslane.io/external-name" = "configuration-aws-network"
                            "crossplane.io/composition-resource-name" = "upboundcare-configuration-aws-network"
                        }
                        generateName = "example-"
                        labels = {
                            "crossplane.io/composite" = "example"
                        }
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            name = "configuration-aws-network"
                            organizationName = "upboundcare"
                            public = True
                            publish = True
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "example-upboundcare-reposet"
                        }
                    }
                }
                {
                    apiVersion = "repository.upbound.io/v1alpha1"
                    kind = "Permission"
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "upboundcare-configuration-aws-network-solutions-non-prod-ci-team"
                        }
                        generateName = "example-"
                        labels = {
                            "crossplane.io/composite" = "example"
                        }
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {
                            organizationName = "upboundcare"
                            permission = "write"
                            repository = "configuration-aws-network"
                            teamIdRef = {
                                name = "solutions-non-prod-ci-team"
                            }
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "example-upboundcare-reposet"
                        }
                    }
                }
                {
                    apiVersion = "repository.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata = {
                        annotations = {
                            "crosslane.io/external-name" = "configuration-aws-network_xnetwork"
                            "crossplane.io/composition-resource-name" = "upboundcare-configuration-aws-network_xnetwork"
                        }
                        generateName = "example-"
                        labels = {
                            "crossplane.io/composite" = "example"
                        }
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            name = "configuration-aws-network_xnetwork"
                            organizationName = "upboundcare"
                            public = False
                            publish = False
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "example-upboundcare-reposet"
                        }
                    }
                }
                {
                    apiVersion = "repository.upbound.io/v1alpha1"
                    kind = "Permission"
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "upboundcare-configuration-aws-network_xnetwork-solutions-non-prod-ci-team"
                        }
                        generateName = "example-"
                        labels = {
                            "crossplane.io/composite" = "example"
                        }
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {
                            organizationName = "upboundcare"
                            permission = "write"
                            repository = "configuration-aws-network_xnetwork"
                            teamIdRef = {
                                name = "solutions-non-prod-ci-team"
                            }
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "example-upboundcare-reposet"
                        }
                    }
                }
            ]
            compositionPath: "apis/xupboundreposets/composition.yaml"
            xrPath: "examples/xupboundreposet/example.yaml"
            xrdPath: "apis/xupboundreposets/definition.yaml"
            timeoutSeconds: 60
            validate: False
        }
    }
]
items= _items
