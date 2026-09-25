import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesm
import models.io.upbound.awsm.iam.v1beta1 as iamv1beta1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.sa.v1 as sav1


_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-environment-deletion-policy-delete"
        spec= {
            assertResources = [
                sav1.Environment{
                    metadata.name = "example"
                    metadata.namespace = "default"
                    spec.parameters = {
                        deletionPolicy = "Delete"
                    }
                }
                kubernetesm.Object{
                    metadata = {
                        name = "example-ctp-kubeconfig"
                    }
                    spec = {
                        forProvider.manifest = {}
                        managementPolicies = ["*"]
                    }
                }
                kubernetesm.Object{
                    metadata = {
                        name = "example-ctp"
                    }
                    spec = {
                        forProvider.manifest = {}
                        managementPolicies = ["*"]
                    }
                }
                kubernetesm.Object{
                    metadata = {
                        name = "solutions-non-prod-default-example-group-kubeconfig"
                    }
                    spec = {
                        forProvider.manifest = {}
                        managementPolicies = ["*"]
                    }
                }
                ### AWS ###
                iamv1beta1.Role{
                    metadata = {
                        name = "upbound-solutions-non-prod-default-example-example-admin"
                    }
                    spec = {
                        forProvider = {}
                        managementPolicies = ["*"]
                    }
                }
                iamv1beta1.RolePolicyAttachment{
                    metadata = {
                        name = "upbound-solutions-non-prod-default-example-example-admin"
                    }
                    spec = {
                        forProvider = {}
                        managementPolicies = ["*"]
                    }
                }
                sav1.SharedAWSSecret{
                    metadata = {
                        name = "example-shared-secret"
                    }
                    spec = {
                        parameters = {
                            deletionPolicy = "Delete"
                            aws = {
                                accountId = "12345678912"
                                region = "us-east-1"
                                namePrefix = "upbound-solutions-non-prod-default-example-example"
                                providerConfigRef = {
                                    name = "solutions-non-prod-default-example"
                                }
                            }
                            upbound = {
                                group = "solutions-non-prod-default-example"
                                controlPlane = "example"
                                providerConfigRef = {
                                    name = "solutions-non-prod-default-example-group"
                                }
                            }
                        }
                    }
                }
                iamv1beta1.OpenIDConnectProvider{
                    metadata = {
                        name = "upbound-solutions-non-prod-default-example-example-oidc-provider"
                    }
                    spec = {
                        forProvider = {}
                        managementPolicies = ["*"]
                    }
                }
            ]
            compositionPath = "apis/environments/composition.yaml"
            xrPath = "examples/environment/example-deletion-policy-delete.yaml"
            xrdPath = "apis/environments/definition.yaml"
            context = {}
            extraResources = []
            observedResources = [
                kubernetesm.Object{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "observedCtpKubeconfig"
                        }
                        name = "observed-bootstrap-ctp-kubeconfig"

                        namespace = "default"
                    }
                    spec = {
                        forProvider = {
                            manifest = {}
                        }
                        managementPolicies = [
                            "Observe"
                        ]
                    }
                    status = {
                        atProvider = {
                            manifest = {
                                data = {
                                    kubeconfig = "YXBpVmVyc2lvbjogdjEKY2x1c3RlcnM6Ci0gY2x1c3RlcjoKICAgIGluc2VjdXJlLXNraXAtdGxzLXZlcmlmeTogdHJ1ZQogICAgc2VydmVyOiBodHRwczovL3VwYm91bmQtYXdzLXVzLWVhc3QtMS5zcGFjZS5teGUudXBib3VuZC5pby9hcGlzL3NwYWNlcy51cGJvdW5kLmlvL3YxYmV0YTEvbmFtZXNwYWNlcy9zb2x1dGlvbnMtbm9uLXByb2QvY29udHJvbHBsYW5lcy9ib290c3RyYXAvazhzCiAgbmFtZTogdXBib3VuZApjb250ZXh0czoKLSBjb250ZXh0OgogICAgY2x1c3RlcjogdXBib3VuZAogICAgZXh0ZW5zaW9uczoKICAgIC0gZXh0ZW5zaW9uOgogICAgICAgIGFwaVZlcnNpb246IHVwYm91bmQuaW8vdjFhbHBoYTEKICAgICAgICBraW5kOiBTcGFjZUV4dGVuc2lvbgogICAgICAgIHNwZWM6CiAgICAgICAgICBjbG91ZDoKICAgICAgICAgICAgb3JnYW5pemF0aW9uOiB1cGJvdW5kCiAgICAgIG5hbWU6IHNwYWNlcy51cGJvdW5kLmlvL3NwYWNlCiAgICBuYW1lc3BhY2U6IGRlZmF1bHQKICAgIHVzZXI6IHVwYm91bmQKICBuYW1lOiB1cGJvdW5kCmN1cnJlbnQtY29udGV4dDogdXBib3VuZApraW5kOiBDb25maWcKcHJlZmVyZW5jZXM6IHt9CnVzZXJzOgotIG5hbWU6IHVwYm91bmQKICB1c2VyOgogICAgZXhlYzoKICAgICAgYXBpVmVyc2lvbjogY2xpZW50LmF1dGhlbnRpY2F0aW9uLms4cy5pby92MQogICAgICBhcmdzOgogICAgICAtIG9yZ2FuaXphdGlvbgogICAgICAtIHRva2VuCiAgICAgIGNvbW1hbmQ6IHVwCiAgICAgIGVudjoKICAgICAgLSBuYW1lOiBPUkdBTklaQVRJT04KICAgICAgICB2YWx1ZTogdXBib3VuZAogICAgICAtIG5hbWU6IFVQX1BST0ZJTEUKICAgICAgICB2YWx1ZTogZGVmYXVsdAogICAgICBpbnRlcmFjdGl2ZU1vZGU6IElmQXZhaWxhYmxlCiAgICAgIHByb3ZpZGVDbHVzdGVySW5mbzogZmFsc2UK"
                                }
                            }
                        }
                    }
                }
            ]
            timeoutSeconds = 60
            validate = False
        }
    }
    # Adoption must override deletionPolicy. With an oidcProviderArn supplied the composition
    # is adopting a provider it did not create, and AWS allows only one per URL per account -
    # proidc.upbound.io is shared by every Upbound integration there. Deleting it on teardown
    # would break all of them, so it stays orphaned even though the XR says Delete. The Role
    # beside it is created by us and must still honour Delete.
    metav1alpha1.CompositionTest{
        metadata.name: "test-environment-adopted-oidc-is-orphaned"
        spec = {
            assertResources = [
                iamv1beta1.OpenIDConnectProvider{
                    metadata = {
                        name = "upbound-solutions-non-prod-default-example-example-oidc-provider"
                        annotations = {
                            "crossplane.io/external-name" = "arn:aws:iam::12345678912:oidc-provider/proidc.upbound.io"
                        }
                    }
                    spec = {
                        forProvider = {}
                        managementPolicies = ["Create", "Observe", "Update", "LateInitialize"]
                    }
                }
                iamv1beta1.Role{
                    metadata.name = "upbound-solutions-non-prod-default-example-example-admin"
                    spec = {
                        forProvider = {}
                        managementPolicies = ["*"]
                    }
                }
            ]
            compositionPath = "apis/environments/composition.yaml"
            xrdPath = "apis/environments/definition.yaml"
            xr: sav1.Environment{
                metadata = {
                    name = "example"
                    namespace = "default"
                }
                spec.parameters = {
                    deletionPolicy = "Delete"
                    aws = {
                        accountId = "12345678912"
                        region = "us-east-1"
                        credsSecretRef = {name = "aws-creds-example", namespace = "default"}
                        providerRole = {
                            oidcProviderArn = "arn:aws:iam::12345678912:oidc-provider/proidc.upbound.io"
                        }
                    }
                    upbound = {
                        initKubeconfigSecretRef = {name = "init-kubeconfig"}
                        tokenSecretRef = {name = "upbound-token"}
                    }
                }
                status.upbound = {
                    bootstrapCtp = "bootstrap"
                    bootstrapGroup = "solutions-non-prod"
                    org = "upbound"
                    spaceHost = "upbound-aws-us-east-1.space.mxe.upbound.io"
                }
            }
            timeoutSeconds = 60
            validate = False
        }
    }
]
items = _items
