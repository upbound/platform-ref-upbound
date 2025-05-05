import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.sa.v1 as sav1
import models.io.upbound.repository.v1alpha1 as repositoryv1alpha1


_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-xupboundreposet-repo-config"
        spec= {
            assertResources: [
                repositoryv1alpha1.Repository{
                    metadata = {
                        annotations = {
                            "crosslane.io/external-name" = "test1"
                            "crossplane.io/composition-resource-name" = "test-org-test1"
                        }
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            name = "test1"
                            organizationName = "test-org"
                            public = True
                            publish = False
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "test-xupboundreposet-repo-config-test-org-reposet"
                        }
                    }
                }
                repositoryv1alpha1.Repository{
                    metadata = {
                        annotations = {
                            "crosslane.io/external-name" = "test2"
                            "crossplane.io/composition-resource-name" = "test-org-test2"
                        }
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            name = "test2"
                            organizationName = "test-org"
                            public = True
                            publish = True
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "test-xupboundreposet-repo-config-test-org-reposet"
                        }
                    }
                }
                repositoryv1alpha1.Repository{
                    metadata = {
                        annotations = {
                            "crosslane.io/external-name" = "test3"
                            "crossplane.io/composition-resource-name" = "test-org-test3"
                        }
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            name = "test3"
                            organizationName = "test-org"
                            public = False
                            publish = True
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "test-xupboundreposet-repo-config-test-org-reposet"
                        }
                    }
                }
                repositoryv1alpha1.Repository{
                    metadata = {
                        annotations = {
                            "crosslane.io/external-name" = "test4"
                            "crossplane.io/composition-resource-name" = "test-org-test4"
                        }
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            name = "test4"
                            organizationName = "test-org"
                            public = False
                            publish = False
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "test-xupboundreposet-repo-config-test-org-reposet"
                        }
                    }
                }
            ]
            compositionPath: "apis/xupboundreposets/composition.yaml"
            xr: sav1.XUpboundRepoSet{
                metadata.name = "test-xupboundreposet-repo-config"
                spec.parameters: {
                    organization: "test-org"
                    permissions: {
                        teams: {
                            "test-team": {
                                permission: "write"
                            }
                        }
                    }
                    repositories: {
                        test1: {
                            public: True
                            publish: False
                        }
                        test2: {
                            public: True
                            publish: True
                        }
                        test3: {
                            public: False
                            publish: True
                        }
                        test4: {}
                    }
                    tokenSecretRef: {
                        key: "creds"
                        name: "my-secret"
                    }
                }
            }
            xrdPath: "apis/xupboundreposets/definition.yaml"
            timeoutSeconds: 60
            validate: False
        }
    }
]
items= _items
