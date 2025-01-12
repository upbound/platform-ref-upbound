import models.io.upbound.sa.v1.xenvironment
import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
import models.io.crossplane.kubernetes.v1alpha1 as kubernetesv1alpha1

# imported with `kcl import -m crd crd.yaml` from kube-crd
# and fixed k8s imoprt to `import ..k8s.apimachinery.pkg.apis.meta.v1`
import spacesModels.v1alpha1 as spacesv1alpha1

import aws

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources

# workaround for https://cloud-native.slack.com/archives/C05TC96NWN8/p1736885830442079
oxrMeta =  oxr.metadata
oxrSpec =  oxr.spec
#oxrMeta =  xenvironment.XEnvironment.metadata{**oxr.metadata}
#oxrSpec =  xenvironment.XEnvironment.spec{**oxr.spec}

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

_envGroupName = "{}-{}".format(oxrSpec.parameters.upbound.group, oxrMeta.name)

_upboundKubeconfig = lambda group: str, ctp: str -> any { str({
    apiVersion = "v1"
    clusters = [
        {
            cluster = {
                "insecure-skip-tls-verify" = True
                if ctp == "":
                    server = "https://{}.space.mxe.upbound.io".format(oxrSpec.parameters.upbound.space)
                else:
                    server = "https://{}.space.mxe.upbound.io/apis/spaces.upbound.io/v1beta1/namespaces/{}/controlplanes/{}/k8s".format(oxrSpec.parameters.upbound.space, group, ctp)
            }
            name = "upbound"
        }
    ]
    contexts = [
        {
            context = {
                cluster = "upbound"
                extensions = [
                    {
                        extension = {
                            apiVersion = "upbound.io/v1alpha1"
                            kind = "SpaceExtension"
                            spec = {
                                cloud = {
                                    organization = oxrSpec.parameters.upbound.org
                                }
                            }
                        }
                        name = "spaces.upbound.io/space"
                    }
                ]
                if ctp == "":
                    namespace = group
                else:
                    namespace = "default"
                user = "upbound"
            }
            name = "upbound"
        }
    ]
    "current-context" = "upbound"
    kind = "Config"
    preferences = {}
    users = [
        {
            name = "upbound"
            user = {
                exec = {
                    apiVersion = "client.authentication.k8s.io/v1"
                    args = [
                        "organization"
                        "token"
                    ]
                    command = "up"
                    env = [
                        {
                            name = "ORGANIZATION"
                            value = oxrSpec.parameters.upbound.org
                        }
                        {
                            name = "UP_PROFILE"
                            value = "default"
                        }
                    ]
                    interactiveMode: "IfAvailable"
                    provideClusterInfo = False
                }
            }

        }
    ]
})}

_awsParams = aws.AWSInput{
    accountId = oxrSpec.parameters.aws.accountId
    awsCredsSecretRef = {
        namespace = "default"
        name = "aws-creds-{}".format(oxrMeta.name)
        key = "credentials"
    }
    namePrefix = "{}-{}-{}".format(oxrSpec.parameters.upbound.org, _envGroupName, oxrMeta.name)
    region = oxrSpec.parameters.aws.region
    envName = _envGroupName
    upboundOrg = oxrSpec.parameters.upbound.org
    rootCtp = oxrSpec.parameters.upbound.ctp
    ocds = _ocds
    oidcProviderArn: oxrSpec.parameters.aws.oidcProviderArn
    secretsManagerSecretArn: oxrSpec.parameters.aws.secretsManagerSecretArn
}

_items = aws.getItems(_awsParams) + [
    kubernetesv1alpha2.Object{
        metadata = _metadata("ctp") | {
            name = "{}-ctp".format(oxrMeta.name)
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                manifest = {
                    apiVersion = "spaces.upbound.io/v1beta1"
                    kind = "ControlPlane"
                    metadata = {
                        name = oxrMeta.name
                        namespace = _envGroupName
                    }
                    spec = {
                        class = "default"
                        crossplane = {
                            autoUpgrade = {
                                channel = "Rapid"
                            }
                        }
                    }
                }
            }
        }
    }

    kubernetesv1alpha2.Object{
        metadata = _metadata("sharedExternalSecret") | {
            name = "{}-ses".format(oxrMeta.name)
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                manifest = spacesv1alpha1.SharedExternalSecret{
                    metadata = {
                        name = oxrMeta.name
                        namespace = _envGroupName
                    }
                    spec = {
                        controlPlaneSelector = {
                            names = [oxrMeta.name]
                        }
                        namespaceSelector = {
                            names = ["default"]
                        }
                        externalSecretSpec = {
                            refreshInterval = "1m"
                            secretStoreRef = {
                                name = oxrMeta.name
                                kind = "ClusterSecretStore"
                            }
                            target = {
                                name = oxrMeta.name
                            }
                            dataFrom = [{
                                extract = {
                                    key = "{}-config".format(_awsParams.namePrefix)
                                }
                            }]
                        }
                    }
                }
            }
            providerConfigRef = {
                name = "{}-group".format(_envGroupName)
            }
        }
    }

    kubernetesv1alpha2.Object{
        metadata = _metadata("sharedSecretsStore") | {
            name = "{}-sss".format(oxrMeta.name)
        }
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                manifest = spacesv1alpha1.SharedSecretStore{
                    metadata = {
                        name = oxrMeta.name
                        namespace = _envGroupName
                    }
                    spec = {
                        controlPlaneSelector = {
                            names = [oxrMeta.name]
                        }
                        namespaceSelector = {
                            names = ["default"]
                        }
                        provider = {
                            aws = {
                                service = "SecretsManager"
                                region = oxrSpec.parameters.aws.region
                                auth = {
                                    secretRef = {
                                        accessKeyIDSecretRef = {
                                            name = "{}-secrets-read-access-key".format(_envGroupName)
                                            key = "username"
                                        }
                                        secretAccessKeySecretRef = {
                                            name = "{}-secrets-read-access-key".format(_envGroupName)
                                            key = "password"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            providerConfigRef = {
                name = "{}-group".format(_envGroupName)
            }
        }
    }

    kubernetesv1alpha2.Object{
        metadata = _metadata("envGroupKubeconfig") | {
            name = "{}-group-kubeconfig".format(_envGroupName)
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Secret"
                    metadata = {
                        name = "{}-group-kubeconfig".format(_envGroupName)
                        namespace = "default"
                    }
                    stringData = {
                        kubeconfig = _upboundKubeconfig("{}-{}".format(_envGroupName, oxrMeta.name), "")
                    }
                }
            }
            providerConfigRef = {
                name = "{}-ctp".format(oxrSpec.parameters.upbound.ctp)
            }
        }
    }

    kubernetesv1alpha1.ProviderConfig{
        metadata = _metadata("envGroupProviderConfig") | {
            name = "{}-group".format(_envGroupName)
            annotations = {
              "krm.kcl.dev/ready" = "True"
            }
        }
        spec = {
            credentials = {
                source = "Secret"
                secretRef = {
                    name = "{}-group-kubeconfig".format(_envGroupName)
                    namespace = "default"
                    key = "kubeconfig"
                }
            }
            identity = {
                type = "UpboundTokens"
                source = "Secret"
                secretRef = {
                    name = "{}-{}-token".format(oxrSpec.parameters.upbound.group, oxrSpec.parameters.upbound.ctp)
                    namespace = "default"
                    key = "token"
                }
            }
        }
    }

    kubernetesv1alpha2.Object{
        metadata = _metadata("envCtpKubeconfig") | {
            name = "{}-ctp-kubeconfig".format(oxrMeta.name)
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Secret"
                    metadata = {
                        name = "{}-ctp-kubeconfig".format(oxrMeta.name)
                        namespace = "default"
                    }
                    stringData = {
                        kubeconfig = _upboundKubeconfig("{}-{}".format(oxrSpec.parameters.upbound.group, oxrMeta.name), oxrMeta.name)
                    }
                }
            }
            providerConfigRef = {
                name = "{}-ctp".format(oxrSpec.parameters.upbound.ctp)
            }
        }
    }


    kubernetesv1alpha1.ProviderConfig{
        metadata = _metadata("envCtpProviderConfig") | {
            name = "{}-ctp".format(oxrMeta.name)
            annotations = {
              "krm.kcl.dev/ready" = "True"
            }
        }
        spec = {
            credentials = {
                source = "Secret"
                secretRef = {
                    name = "{}-ctp-kubeconfig".format(oxrMeta.name)
                    namespace = "default"
                    key = "kubeconfig"
                }
            }
            identity = {
                type = "UpboundTokens"
                source = "Secret"
                secretRef = {
                    # @TODO one token per env
                    name = "{}-{}-token".format(oxrSpec.parameters.upbound.group, oxrSpec.parameters.upbound.ctp)
                    namespace = "default"
                    key = "token"
                }
            }
        }
    }

]

items = _items
