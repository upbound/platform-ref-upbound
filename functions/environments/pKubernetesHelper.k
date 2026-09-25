"""
Helper module that provides functions for configuring Kubernetes providers and
generating kubeconfig objects for connecting to Upbound Spaces.

This module supports creating provider configurations at different scopes:
- Space level: For accessing APIs at the Upbound Spaces level
- Group level: For accessing APIs at the environment group level
- Control plane level: For accessing APIs within a specific control plane
"""

import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesm
import models.io.crossplane.protection.v1beta1 as protectionv1beta1
import base64
import utils

schema UpboundTokenSecretRef:
    name: str
    namespace: str
    key: str

schema UpboundProviderConfigInput:
    """
    Input schema for configuring a Kubernetes provider for Upbound Spaces.
    Exactly one of group+ctp or prefix must be provided to determine the scope.
    """
    spaceHost: str  # The Upbound Spaces host (e.g. spaces.upbound.io)
    org: str        # The Upbound organization name
    group?: str     # Optional: The group name for group-level access
    ctp?: str       # Optional: The control plane name for control plane-level access
    # should be set when neither group nor ctp is set
    prefix?: str    # Optional: Prefix for space-level access (when no group/ctp provided)
    providerConfigName: str  # Name of the provider config to reference
    # Namespace on the bootstrap control plane for the kubeconfig Secret - the XR's own.
    # A shared `default` would make same-named Environments in different namespaces
    # overwrite each other's credentials.
    secretNamespace: str
    upboundTokenSecretRef: UpboundTokenSecretRef        # Reference to the Upbound authentication token

# Helper for generating a controlplane, space or group-level kubeconfig for provider-kubernetes on upbound
# This function creates a kubeconfig that targets the appropriate API endpoint based on the scope:
# - If ctp and group are provided: Targets a specific control plane within a group
# - If only group is provided: Targets all control planes within a group
# - If neither is provided: Targets the space-level APIs
upboundKubeconfig = lambda spaceHost: str, org: str, group: str, ctp: str -> any { str({
    apiVersion = "v1"
    clusters = [
        {
            cluster = {
                "insecure-skip-tls-verify" = True
                if ctp == "":
                    server = "https://{}".format(spaceHost)
                else:
                    server = "https://{}/apis/spaces.upbound.io/v1beta1/namespaces/{}/controlplanes/{}/k8s".format(spaceHost, group, ctp)
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
                                    organization = org
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
                            value = org
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

configName = lambda group: str, ctp: str, prefix: str -> any {
   """
   Generates a configuration name based on the scope:
   - For control plane scope: "<ctp>-ctp"
   - For group scope: "<group>-group"
   - For space scope: "<prefix>-space"
   """
   "{}-ctp".format(ctp) if ctp else ("{}-group".format(group) if group else "{}-space".format(prefix))
}

resourceName = lambda group: str, ctp: str -> any {
   """
   Generates a resource name identifier based on the scope:
   - For control plane scope: "envCtp"
   - For group scope: "envGroup"
   - For space scope: "space"
   """
   "envCtp" if ctp else ("envGroup" if group else "space")
}

upboundProviderConfig = lambda config: UpboundProviderConfigInput -> any {
   """
   Creates a complete Kubernetes provider configuration bundle for Upbound Spaces, including:
   1. A Kubernetes Object to store the kubeconfig secret
   2. A ProviderConfig that references the kubeconfig secret
   3. A Usage resource to establish dependency between the secret and provider config

   Returns a list of these three resources properly configured for the specified scope.
   """
   [
        kubernetesm.Object{
            metadata = utils._metadata("{}Kubeconfig".format(resourceName(config.group, config.ctp))) | {
                name = "{}-kubeconfig".format(configName(config.group, config.ctp, config.prefix))
            }
            spec = {
                forProvider = {
                    manifest = {
                        apiVersion = "v1"
                        kind = "Secret"
                        metadata = {
                            name = "{}-kubeconfig".format(configName(config.group, config.ctp, config.prefix))
                            namespace = config.secretNamespace
                        }
                        # `data` with base64, not `stringData`. provider-kubernetes applies
                        # server-side and records field ownership for what it wrote; because
                        # Kubernetes converts stringData -> data on write, the owned field is
                        # never present on the stored object and the next observe fails with
                        # "unable to convert managed fields ... expected map, got <nil>".
                        data = {
                            kubeconfig = base64.encode(upboundKubeconfig(
                                            config.spaceHost,
                                            config.org,
                                            config.group if config.group else "default",
                                            config.ctp if config.ctp else ""))
                        }
                    }
                }
                providerConfigRef = {
                    kind = "ProviderConfig"
                    name = config.providerConfigName
                }
            }
        }

        kubernetesm.ProviderConfig{
            metadata = utils._metadata("{}ProviderConfig".format(resourceName(config.group, config.ctp))) | {
                name = configName(config.group, config.ctp, config.prefix)
                annotations = {
                  "krm.kcl.dev/ready" = "True"
                }
            }
            spec = {
                credentials = {
                    source = "Secret"
                    secretRef = {
                        name = "{}-kubeconfig".format(configName(config.group, config.ctp, config.prefix))
                        namespace = config.secretNamespace
                        key = "kubeconfig"
                    }
                }
                identity = {
                    type = "UpboundTokens"
                    source = "Secret"
                    secretRef = {
                        # Uses the token from the shared bootstrap control plane
                        name = config.upboundTokenSecretRef.name
                        namespace = config.upboundTokenSecretRef.namespace
                        key = config.upboundTokenSecretRef.key
                    }
                }
            }
        }

        protectionv1beta1.Usage{
            metadata = utils._metadata("{}Usage".format(resourceName(config.group, config.ctp))) | {
                name = "{}-kubeconfig".format(configName(config.group, config.ctp, config.prefix))
            }
            spec = {
                replayDeletion = True
                of = {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    resourceRef = {
                        name = "{}-kubeconfig".format(configName(config.group, config.ctp, config.prefix))
                    }
                }
                by = {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "ProviderConfig"
                    resourceRef = {
                        name = configName(config.group, config.ctp, config.prefix)
                    }
                }
            }
        }
]}

