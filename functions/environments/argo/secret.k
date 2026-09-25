import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesm
import models.io.k8s.api.core.v1 as v1
import utils
import json
import base64

argoServerSecret = lambda config: ArgoServerSecret -> any {
   """
   Creates a ArgoCD Server Secret.
   """
   [
        kubernetesm.Object{
            metadata = utils._metadata("ctp-argocd") | {
                name = "{}-ctp-argocd-secret".format(config.ctp)
            }
            spec = {
                forProvider = {
                    manifest = v1.Secret{
                        metadata: {
                            name: "{}-{}".format(config.group,config.ctp)
                            namespace: "argocd"
                            labels: {
                                "argocd.argoproj.io/secret-type": "cluster"
                            }
                        }
                        type: "Opaque"
                        # base64 `data`, not `stringData` - see pKubernetesHelper.k for why
                        # provider-kubernetes cannot observe a stringData-owned field.
                        data: {
                            name: base64.encode("{}-{}".format(config.group,config.ctp))
                            server: base64.encode("https://{}/apis/spaces.upbound.io/v1beta1/namespaces/{}/controlplanes/{}/k8s".format(config.spaceHost, config.group, config.ctp))
                            config: base64.encode(json.encode({
                                execProviderConfig: {
                                    apiVersion: "client.authentication.k8s.io/v1"
                                    command: "up"
                                    args: [
                                        "org"
                                        "token"
                                    ]
                                    env: {
                                        "ORGANIZATION": config.org
                                        "UP_TOKEN": config.accessToken
                                    }
                                }
                                tlsClientConfig: {
                                    insecure: False
                                    caData: config.serverCaData
                                }
                            }))
                        }
                    }
                }
                providerConfigRef = {
                    kind = "ProviderConfig"
                    name = config.providerConfigName
                }
            }
        }
]}
