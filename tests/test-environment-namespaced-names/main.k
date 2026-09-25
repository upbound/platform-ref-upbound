"""
Environment names must not collide across namespaces.

With a Namespaced XRD, team-a/prod and team-b/prod are both valid, and everything the
composition creates *outside* the XR's namespace has to tell them apart: the Upbound group
(and so the ControlPlane, Team, Robot and Argo secret inside or named after it), the AWS
resource names, and the kubeconfig Secrets on the bootstrap control plane. Built from
metadata.name alone, the two map to the same objects - and with deletionPolicy: Delete,
deleting one tears down the other.
"""

import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesm
import models.io.upbound.awsm.iam.v1beta1 as iamv1beta1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.sa.v1 as sav1

_xr = lambda namespace: str, name: str -> sav1.Environment {
    sav1.Environment{
        metadata = {
            name = name
            namespace = namespace
        }
        spec.parameters = {
            deletionPolicy = "Delete"
            aws = {
                accountId = "12345678912"
                region = "us-east-1"
                credsSecretRef = {name = "aws-creds-example", namespace = namespace}
                providerRole = {}
            }
            upbound = {
                initKubeconfigSecretRef = {name = "init-kubeconfig", namespace = namespace}
                tokenSecretRef = {name = "upbound-token", namespace = namespace}
            }
        }
        status.upbound = {
            bootstrapCtp = "bootstrap"
            bootstrapGroup = "solutions-non-prod"
            org = "upbound"
            spaceHost = "upbound-aws-us-east-1.space.mxe.upbound.io"
        }
    }
}

_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-environment-namespaced-names"
        spec = {
            assertResources = [
                # The group carries the namespace, so team-b/example gets a different one.
                kubernetesm.Object{
                    metadata.name = "solutions-non-prod-team-a-example"
                    spec.forProvider.manifest.metadata.name = "solutions-non-prod-team-a-example"
                }
                kubernetesm.Object{
                    metadata.name = "example-ctp"
                    spec.forProvider.manifest.metadata.namespace = "solutions-non-prod-team-a-example"
                }
                # Kubeconfig Secrets land in the XR's own namespace rather than a shared
                # `default`, and the ProviderConfig reads them from there.
                kubernetesm.Object{
                    metadata.name = "solutions-non-prod-team-a-example-group-kubeconfig"
                    spec.forProvider.manifest.metadata = {
                        name = "solutions-non-prod-team-a-example-group-kubeconfig"
                        namespace = "team-a"
                    }
                }
                kubernetesm.ProviderConfig{
                    metadata.name = "solutions-non-prod-team-a-example-group"
                    spec.credentials = {
                        source = "Secret"
                        secretRef = {
                            name = "solutions-non-prod-team-a-example-group-kubeconfig"
                            namespace = "team-a"
                            key = "kubeconfig"
                        }
                    }
                }
                kubernetesm.Object{
                    metadata.name = "example-ctp-kubeconfig"
                    spec.forProvider.manifest.metadata.namespace = "team-a"
                }
                kubernetesm.Object{
                    metadata.name = "example-space-kubeconfig"
                    spec.forProvider.manifest.metadata.namespace = "team-a"
                }
                # AWS names follow the group, so they are distinct too.
                iamv1beta1.Role{
                    metadata.name = "upbound-solutions-non-prod-team-a-example-example-admin"
                    spec.forProvider = {}
                }
            ]
            compositionPath = "apis/environments/composition.yaml"
            xrdPath = "apis/environments/definition.yaml"
            xr: _xr("team-a", "example")
            timeoutSeconds = 60
            validate = False
        }
    }
    # Adding the namespace lengthens every AWS name. IAM caps role names at 64 characters,
    # and a real org/group/namespace/name combination passes that easily - AWS would then
    # reject the Role outright. It gets the same truncation SharedAWSSecret already applies
    # to its IAM user and policy: keep the suffix, replace the tail of the prefix with a hash.
    metav1alpha1.CompositionTest{
        metadata.name: "test-environment-long-role-name"
        spec = {
            assertResources = [
                iamv1beta1.Role{
                    # 81 characters untruncated.
                    metadata.name = "upbound-solutions-non-prod-platform-engineering-p-289801-admin"
                    spec.forProvider = {}
                }
            ]
            compositionPath = "apis/environments/composition.yaml"
            xrdPath = "apis/environments/definition.yaml"
            xr: _xr("platform-engineering", "production-eu")
            timeoutSeconds = 60
            validate = False
        }
    }
]

items = _items
