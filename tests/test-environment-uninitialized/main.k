import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesm
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.sa.v1 as sav1

# The first reconcile of any Environment happens before status.upbound exists. The function
# must emit only the bootstrap-kubeconfig observer and wait, rather than aborting the
# pipeline. Nothing else covers this: every other suite supplies a populated status, either
# in its example or inline, so the uninitialised branch was never rendered.
_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-environment-uninitialized"
        spec = {
            assertResources: [
                kubernetesm.Object{
                    metadata.name = "fresh-bootstrap-ctp-kubeconfig-observed"
                    spec = {
                        forProvider = {
                            manifest = {
                                apiVersion = "v1"
                                kind = "Secret"
                                metadata = {
                                    name = "bootstrap-kubeconfig"
                                    namespace = "default"
                                }
                            }
                        }
                        managementPolicies = ["Observe"]
                        providerConfigRef = {
                            kind = "ProviderConfig"
                            name = "bootstrap-ctp"
                        }
                    }
                }
            ]
            compositionPath: "apis/environments/composition.yaml"
            xrdPath: "apis/environments/definition.yaml"
            xr: sav1.Environment{
                metadata = {
                    name = "fresh"
                    namespace = "default"
                }
                # `upbound = None`, not an absent status: this is the exact shape a brand new
                # XR has on a live control plane, and it is what distinguishes a correct guard
                # from one written against Undefined.
                status = {
                    upbound = None
                }
                spec = {
                    parameters = {
                        upbound = {
                            initKubeconfigSecretRef = {
                                name = "bootstrap-kubeconfig"
                                namespace = "default"
                            }
                            tokenSecretRef = {
                                name = "bootstrap-token"
                                namespace = "default"
                            }
                        }
                    }
                }
            }
            timeoutSeconds: 60
            validate: False
        }
    }
]
items = _items
