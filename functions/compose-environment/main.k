"""
This KCL function implements the core composition logic for XEnvironment resources.
It automates the creation and management of Upbound Spaces environments with
integrated AWS cloud resources. The function handles:
- Environment initialization using bootstrap credentials
- Control plane creation in Upbound Spaces
- Kubernetes provider configurations for various scopes (space/group/control plane)
- AWS IAM role and policy setup for cross-service authentication
- Secret management between AWS Secrets Manager and Upbound Spaces
"""

import models.io.upbound.sa.v1 as sav1
import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2

# sytem modules
import base64
import yaml
import regex

# our modules
import aws.providerConfig as awsProviderConfig
import aws.secretStore as awsSS
import aws.crossplaneRole as awsXPRole
import pKubernetesHelper
import teamRobot
import bootstrapSecretSync

oxr = option("params").oxr # observed composite resource
ocds = option("params").ocds # observed composed resources
dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources

oxrMeta =  sav1.XEnvironment.metadata{**oxr.metadata}
oxrSpec =  sav1.XEnvironment.spec{**oxr.spec}

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

# =========================================================================
# Initial Kubeconfig Processing
# =========================================================================
# First try to read the configuration from initial kubeconfig
# Because the kubeconfig is coming from an external process and we are creating resources
# conditionally based on the fact if these values are set, we first transfer them to the
# status of the XR later in order to prevent losing resources in case the kubeconfig is deleted
#
# This initialization flow:
# 1. Extracts key metadata from bootstrap kubeconfig (org, group, control plane name, etc)
# 2. Stores these values in XEnvironment status for future reconciliations
# 3. Creates resources only after the metadata is properly established

_initKubeconfigServerUrl = Undefined
_upboundSpaceHostFromKubeconfig = Undefined
_upboundBootstrapGroupFromKubeconfig = Undefined
_upboundBootstrapCtpFromKubeconfig = Undefined
_upboundOrgFromKubeconfig = Undefined

# Parse configuration from initial kubeconfig and the contained server-url
# we will then pass the config to the `status.upbound` field of the XR
_initialKubeconfig = ocds.observedCtpKubeconfig?.Resource?.status?.atProvider?.manifest?.data?.kubeconfig
if _initialKubeconfig:
    _initKubeconfigServerUrl = yaml.decode(base64.decode(_initialKubeconfig)).clusters[0]?.cluster?.server
    _upboundSpaceHostFromKubeconfig = regex.replace(_initKubeconfigServerUrl, "https:\/\/([.\w-]+)(?:\/[.\w-]+){8}", "$1")
    _upboundBootstrapGroupFromKubeconfig = regex.replace(_initKubeconfigServerUrl, "https:\/(?:\/[.\w-]+){5}\/([.\w-]+)(?:\/[.\w-]+){3}", "$1")
    _upboundBootstrapCtpFromKubeconfig = regex.replace(_initKubeconfigServerUrl, "https:\/(?:\/[.\w-]+){7}\/([.\w-]+)(?:\/[.\w-]+)", "$1")
    _upboundOrgFromKubeconfig = yaml.decode(base64.decode(_initialKubeconfig)).contexts[0].context.extensions[0].extension.spec.cloud.organization

# Readiness-check for proceeding with read from status
_oxrStatusUpbound = oxr.status?.upbound
_initReady = _oxrStatusUpbound != Undefined and \
    _oxrStatusUpbound.org != Undefined and \
    _oxrStatusUpbound.bootstrapCtp != Undefined and \
    _oxrStatusUpbound.bootstrapGroup != Undefined and \
    _oxrStatusUpbound.spaceHost != Undefined

_initItems = [
    sav1.XEnvironment{
        spec = {}
        status = {
            upbound = {
                bootstrapCtp = _upboundBootstrapCtpFromKubeconfig
                bootstrapGroup = _upboundBootstrapGroupFromKubeconfig
                org = _upboundOrgFromKubeconfig
                spaceHost = _upboundSpaceHostFromKubeconfig
            }
        }
    }

    # observed kubeconfig for bootstrap-ctp, will be used to derive settings
    # like upbound org, bootstrap-group, bootstrap-controlplane and space host
    kubernetesv1alpha2.Object{
        metadata = _metadata("observedCtpKubeconfig") | {
            name = "{}-bootstrap-ctp-kubeconfig-observed".format(oxrMeta.name)
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Secret"
                    metadata = {
                        name = oxrSpec.parameters.upbound.initKubeconfigSecretRef.name
                        namespace = oxrSpec.parameters.upbound.initKubeconfigSecretRef.namespace
                    }
                }
            }
            providerConfigRef = {
                name = oxrSpec.parameters.upbound.initProviderConfigName
            }
            managementPolicies = ["Observe"]
        }
    }
]

_upboundItems = []
_awsItems = []

if _initReady:
    # =========================================================================
    # Environment Resource Creation
    # =========================================================================
    # Now that we have verified initialization data is present, we can create
    # all the resources needed for the environment:
    # - Upbound control plane in Spaces
    # - Kubernetes provider configurations for access
    # - AWS IAM role setup for cross-service authentication
    # - Secret stores and external secrets for configuration

    # Every environment consists of a group containing a single controlplane, this is the name of that group
    envGroupName = "{}-{}".format(_oxrStatusUpbound.bootstrapGroup, oxrMeta.name)
    awsNamePrefix = "{}-{}-{}".format(_oxrStatusUpbound.org, envGroupName, oxrMeta.name)

    _upboundItems = [
        # Main controlplane for the environment
        if oxrSpec.parameters.upbound.createCtp:
            kubernetesv1alpha2.Object{
                metadata = _metadata("ctp") | {
                    name = "{}-ctp".format(oxrMeta.name)
                }
                spec = {
                    deletionPolicy = oxrSpec.parameters.deletionPolicy
                    forProvider = {
                        manifest = {
                            apiVersion = "spaces.upbound.io/v1beta1"
                            kind = "ControlPlane"
                            metadata = {
                                name = oxrMeta.name
                                namespace = envGroupName
                                annotations = {
                                    foo = str(oxrSpec)
                                }
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
                    providerConfigRef = {
                        name = "{}-group".format(envGroupName)
                    }
                }
            }

        if oxrSpec.parameters.upbound.createGroup:
            kubernetesv1alpha2.Object{
                metadata = _metadata("envGroup") | {
                    name = envGroupName
                }
                spec = {
                    deletionPolicy = oxrSpec.parameters.deletionPolicy
                    forProvider = {
                        manifest = {
                            apiVersion = "v1"
                            kind = "Namespace"
                            metadata = {
                                name = envGroupName
                            }
                        }
                    }
                    providerConfigRef = {
                        name = "{}-space".format(oxrMeta.name)
                    }
                }
            }
    ]
    if oxrSpec.parameters.upbound.createCtp:
        _upboundItems += pKubernetesHelper.upboundProviderConfig(pKubernetesHelper.UpboundProviderConfigInput{
            # controlplane level providerconfig for provider-kubernetes
            spaceHost = _oxrStatusUpbound.spaceHost
            org = _oxrStatusUpbound.org
            group = envGroupName
            ctp = oxrMeta.name
            providerConfigName = "{}-ctp".format(_oxrStatusUpbound.bootstrapCtp)
            upboundTokenSecretRef = pKubernetesHelper.UpboundTokenSecretRef{
                name = oxrSpec.parameters.upbound.tokenSecretRef.name
                namespace = oxrSpec.parameters.upbound.tokenSecretRef.namespace
                key = oxrSpec.parameters.upbound.tokenSecretRef.key
            }
        })

    if oxrSpec.parameters.upbound.createGroup:
        _upboundItems += pKubernetesHelper.upboundProviderConfig(pKubernetesHelper.UpboundProviderConfigInput{
            # environment group level providerconfig for provider-kubernetes
            spaceHost = _oxrStatusUpbound.spaceHost
            org = _oxrStatusUpbound.org
            group = envGroupName
            providerConfigName = "{}-ctp".format(_oxrStatusUpbound.bootstrapCtp)
            upboundTokenSecretRef = pKubernetesHelper.UpboundTokenSecretRef{
                name = oxrSpec.parameters.upbound.tokenSecretRef.name
                namespace = oxrSpec.parameters.upbound.tokenSecretRef.namespace
                key = oxrSpec.parameters.upbound.tokenSecretRef.key
            }
        })

    if oxrSpec.parameters.upbound.createGroup:
        _upboundItems += pKubernetesHelper.upboundProviderConfig(pKubernetesHelper.UpboundProviderConfigInput{
            # space level providerconfig for provider-kubernetes
            spaceHost = _oxrStatusUpbound.spaceHost
            org = _oxrStatusUpbound.org
            prefix = oxrMeta.name
            providerConfigName = "{}-ctp".format(_oxrStatusUpbound.bootstrapCtp)
            upboundTokenSecretRef = pKubernetesHelper.UpboundTokenSecretRef{
                name = oxrSpec.parameters.upbound.tokenSecretRef.name
                namespace = oxrSpec.parameters.upbound.tokenSecretRef.namespace
                key = oxrSpec.parameters.upbound.tokenSecretRef.key
            }
        })

    # If creation of team with robot is enabled
    if oxrSpec.parameters.upbound.teamWithRobot != Undefined:
        _upboundItems += teamRobot.teamWithRobot(teamRobot.TeamWithRobotInput{
            group = envGroupName
            org = _oxrStatusUpbound.org
            secretDestProviderConfigName = "{}-ctp".format(oxrMeta.name)
            spaceProviderConfigName = "{}-space".format(oxrMeta.name)
            ocds = ocds
            teamNameOverride = oxrSpec.parameters.upbound.teamWithRobot.teamNameOverride
            teamExternalName = oxrSpec.parameters.upbound.teamWithRobot.teamExternalName
            tokenSecretRef = teamRobot.TeamRobotTokenSecretRef{
                name = oxrSpec.parameters.upbound.tokenSecretRef.name
                namespace = oxrSpec.parameters.upbound.tokenSecretRef.namespace
                key = oxrSpec.parameters.upbound.tokenSecretRef.key
            }
            createGroupAdminBinding = oxrSpec.parameters.upbound.createGroup
        })

    if oxrSpec.parameters.upbound.secretSync:
        _upboundItems += bootstrapSecretSync.syncedSecrets([bootstrapSecretSync.SecretSyncInput{
            sourceRef = {
                name = secret.sourceRef.name
                namespace = secret.sourceRef.namespace
            }
            destRef = {
                name = secret.destRef.name
                namespace = secret.destRef.namespace
            }
            providerConfigName = "{}-ctp".format(oxrMeta.name)
        } for secret in oxrSpec.parameters.upbound.secretSync])

    # If aws features are enabled
    if oxrSpec.parameters.aws != Undefined:
        # create providerconfig for aws
        _awsItems += awsProviderConfig.getProviderConfig(awsProviderConfig.AWSProviderConfigInput{
            if oxrSpec.parameters.aws.roleArn:
                awsRoleArn = oxrSpec.parameters.aws.roleArn
            if oxrSpec.parameters.aws.credsSecretRef:
                awsCredsSecretRef = {
                    namespace = oxrSpec.parameters.aws.credsSecretRef.namespace
                    name = oxrSpec.parameters.aws.credsSecretRef.name
                    key = "credentials"
                }
            envName = envGroupName
        })

        # if creation of provider role is enabled
        if oxrSpec.parameters.aws.providerRole != Undefined:
            _awsItems += awsXPRole.getXPRoleItems(awsXPRole.AWSXPRoleInput{
                accountId = oxrSpec.parameters.aws.accountId
                deletionPolicy = oxrSpec.parameters.deletionPolicy
                envName = envGroupName
                ctpName = oxrMeta.name
                namePrefix = "{}-{}-{}".format(_oxrStatusUpbound.org, envGroupName, oxrMeta.name)
                oidcProviderArn: oxrSpec.parameters.aws?.providerRole?.oidcProviderArn
                region = oxrSpec.parameters.aws.region
                upboundOrg = _oxrStatusUpbound.org
            })

        # if creation of shared secret is enabled
        if oxrSpec.parameters.aws.sharedSecret != Undefined:
            _awsItems += awsSS.getSecretStoreItems(awsSS.AWSSecretStoreInput{
                accountId = oxrSpec.parameters.aws.accountId
                deletionPolicy = oxrSpec.parameters.deletionPolicy
                ctpName = oxrMeta.name
                envName = envGroupName
                namePrefix = "{}-{}-{}".format(_oxrStatusUpbound.org, envGroupName, oxrMeta.name)
                region = oxrSpec.parameters.aws.region
                rootCtp = _oxrStatusUpbound.bootstrapCtp
                secretsManagerSecretArn: oxrSpec.parameters.aws?.sharedSecret?.secretsManagerSecretArn
            })

# Return final resource list
items = _initItems + _upboundItems + _awsItems
