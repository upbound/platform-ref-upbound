import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.sa.v1 as sav1
import models.io.upbound.repositorym.v1alpha1 as repositoryv1alpha1


_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-upboundreposet-repo-config"
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
                        forProvider = {
                            name = "test1"
                            organizationName = "test-org"
                            public = True
                            publish = False
                        }
                        managementPolicies = [
                            "Create"
                            "Observe"
                            "Update"
                            "LateInitialize"
                        ]
                        providerConfigRef = {
                            kind = "ProviderConfig"
                            name = "test-upboundreposet-repo-config-test-org-reposet"
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
                        forProvider = {
                            name = "test2"
                            organizationName = "test-org"
                            public = True
                            publish = True
                        }
                        managementPolicies = [
                            "Create"
                            "Observe"
                            "Update"
                            "LateInitialize"
                        ]
                        providerConfigRef = {
                            kind = "ProviderConfig"
                            name = "test-upboundreposet-repo-config-test-org-reposet"
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
                        forProvider = {
                            name = "test3"
                            organizationName = "test-org"
                            public = False
                            publish = True
                        }
                        managementPolicies = [
                            "Create"
                            "Observe"
                            "Update"
                            "LateInitialize"
                        ]
                        providerConfigRef = {
                            kind = "ProviderConfig"
                            name = "test-upboundreposet-repo-config-test-org-reposet"
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
                        forProvider = {
                            name = "test4"
                            organizationName = "test-org"
                            public = False
                            publish = False
                        }
                        managementPolicies = [
                            "Create"
                            "Observe"
                            "Update"
                            "LateInitialize"
                        ]
                        providerConfigRef = {
                            kind = "ProviderConfig"
                            name = "test-upboundreposet-repo-config-test-org-reposet"
                        }
                    }
                }
            ]
            compositionPath: "apis/upboundreposets/composition.yaml"
            xr: sav1.UpboundRepoSet{
                metadata.name = "test-upboundreposet-repo-config"
                metadata.namespace = "default"
                spec.parameters: {
                    organization: "test-org"
                    settings: {
                        public: False
                        publish: False
                    }
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
            xrdPath: "apis/upboundreposets/definition.yaml"
            timeoutSeconds: 60
            validate: False
        }
    }
]
items= _items
