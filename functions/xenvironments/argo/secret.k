import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
import models.io.k8s.api.core.v1 as v1
import utils
import json

argoServerSecret = lambda config: ArgoServerSecret -> any {
   """
   Creates a ArgoCD Server Secret.
   """
   [
        kubernetesv1alpha2.Object{
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
                        stringData: {
                            name: "{}-{}".format(config.group,config.ctp)
                            server: "https://{}/apis/spaces.upbound.io/v1beta1/namespaces/{}/controlplanes/{}/k8s".format(config.spaceHost, config.group, config.ctp)
                            config: json.encode({
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
                            })
                        }
                    }
                }
                providerConfigRef = {
                    name = config.providerConfigName
                }
            }
        }
]}