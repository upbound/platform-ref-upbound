import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesm
import models.io.k8s.api.core.v1 as v1

observeSecret = lambda config: ObserveSecret -> any {
   """
   Observe a Secret.
   """
   [
        kubernetesm.Object{
            metadata = _metadata(config.resourceName) | {
                name = "{}-{}-observed".format(config.ctp, config.resourceName)
            }
            spec = {
                forProvider = {
                    manifest = v1.Secret{
                        metadata = {
                            name = config.name
                            namespace = config.namespace
                        }
                    }
                }
                providerConfigRef = {
                    kind = "ProviderConfig"
                    name = config.providerConfigName
                }
                managementPolicies = ["Observe"]
            }
        }
]}
