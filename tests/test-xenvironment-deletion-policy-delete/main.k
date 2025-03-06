import models.io.crossplane.kubernetes.v1alpha1 as kubernetesv1alpha1
import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
import models.io.upbound.aws.iam.v1beta1 as iamv1beta1
import models.io.upbound.aws.secretsmanager.v1beta1 as secretsmanagerv1beta1
import models.io.upbound.aws.v1beta1 as awsv1beta1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.sa.v1 as sav1


_items = [
    metav1alpha1.CompositionTest{
        spec= {
            assertResources = [
                sav1.XEnvironment{
                    metadata.name = "example"
                    spec.parameters = {
                        deletionPolicy = "Delete"
                    }
                }
                kubernetesv1alpha2.Object{
                    metadata = {
                        name = "example-ctp-kubeconfig"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider.manifest = {}
                    }
                }
                kubernetesv1alpha2.Object{
                    metadata = {
                        name = "example-ctp"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider.manifest = {}
                    }
                }
                kubernetesv1alpha2.Object{
                    metadata = {
                        name = "solutions-non-prod-example-group-kubeconfig"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider.manifest = {}
                    }
                }
                kubernetesv1alpha2.Object{
                    kind = "Object"
                    metadata = {
                        name = "solutions-non-prod-example-secrets-read-access-key"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider.manifest = {}
                    }
                }
                ### AWS ###
                iamv1beta1.Role{
                    metadata = {
                        name = "upbound-solutions-non-prod-example-example-admin"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {}
                    }
                }
                iamv1beta1.RolePolicyAttachment{
                    metadata = {
                        name = "upbound-solutions-non-prod-example-example-admin"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {}
                    }
                }
                iamv1beta1.Policy{
                    metadata = {
                        name = "upbound-solutions-non-prod-example-example-secrets-read"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {}
                    }
                }
                iamv1beta1.UserPolicyAttachment{
                    metadata = {
                        name = "upbound-solutions-non-prod-example-example-secrets-read"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {}
                    }
                }
                iamv1beta1.AccessKey{
                    metadata = {
                        name = "upbound-solutions-non-prod-example-example-secrets-read"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {}
                    }
                }
                iamv1beta1.User{
                    metadata = {
                        name = "upbound-solutions-non-prod-example-example-secrets-read"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {}
                    }
                }
                kubernetesv1alpha2.Object{
                    metadata = {
                        name = "solutions-non-prod-example-secrets-read-access-key-observed"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider.manifest = {}
                        managementPolicies = ["Observe"]
                    }
                }
                kubernetesv1alpha2.Object{
                    metadata = {
                        name = "example-ses"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider.manifest = {}
                    }
                }
                kubernetesv1alpha2.Object{
                    metadata = {
                        name = "example-sss"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider.manifest = {}
                    }
                }
                iamv1beta1.OpenIDConnectProvider{
                    metadata = {
                        name = "upbound-solutions-non-prod-example-example-oidc-provider"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {}
                    }
                }
                secretsmanagerv1beta1.Secret{
                    metadata = {
                        name = "upbound-solutions-non-prod-example-example-secretsmanager-secret"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider.region = "us-east-1"
                    }
                }
            ]
            compositionPath = "apis/xenvironments/composition.yaml"
            xrPath = "examples/xenvironment/example-deletion-policy-delete.yaml"
            xrdPath = "apis/xenvironments/definition.yaml"
            context = []
            extraResources = []
            observedResources = [
                kubernetesv1alpha2.Object{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "observedCtpKubeconfig"
                        }
                        name = "observed-bootstrap-ctp-kubeconfig"
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
]
items = _items
