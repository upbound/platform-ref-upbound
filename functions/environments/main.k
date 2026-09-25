"""
This KCL function implements the core composition logic for Environment resources.
It automates the creation and management of Upbound Spaces environments with
integrated AWS cloud resources. The function handles:
- Environment initialization using bootstrap credentials
- Control plane creation in Upbound Spaces
- Server Secret for Argo
- Kubernetes provider configurations for various scopes (space/group/control plane)
- AWS IAM role and policy setup for cross-service authentication
- Secret management between AWS Secrets Manager and Upbound Spaces
"""

import models.io.upbound.sa.v1 as sav1
import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesm

# sytem modules
import base64
import yaml
import regex

# our modules
import aws.providerConfig as awsProviderConfig
import aws.crossplaneRole as awsXPRole
import pKubernetesHelper
import teamRobot
import bootstrapSecretSync
import argo
import utils

oxr = option("params").oxr # observed composite resource
ocds = option("params").ocds # observed composed resources
dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources

oxrMeta =  sav1.Environment.metadata{**oxr.metadata}
# Take only `parameters` rather than spreading the whole observed spec. A namespaced
# (v2) XR also carries spec.crossplane, whose resourceRefs Crossplane populates with
# plain dicts once resources exist - spreading those into the typed schema fails with
# "expect [...SpecCrossplaneResourceRefsItems0], got list".
oxrSpec =  sav1.Environment.spec{parameters = oxr.spec.parameters}

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
# 2. Stores these values in Environment status for future reconciliations
# 3. Creates resources only after the metadata is properly established

_initKubeconfigServerUrl = Undefined
_initKubeconfigServerCaData = Undefined
_upboundSpaceHostFromKubeconfig = Undefined
_upboundBootstrapGroupFromKubeconfig = Undefined
_upboundBootstrapCtpFromKubeconfig = Undefined
_upboundOrgFromKubeconfig = Undefined

# Parse configuration from initial kubeconfig and the contained server-url
# we will then pass the config to the `status.upbound` field of the XR
_initialKubeconfig = ocds.observedCtpKubeconfig?.Resource?.status?.atProvider?.manifest?.data?.kubeconfig
if _initialKubeconfig:
    _initKubeconfigServerUrl = yaml.decode(base64.decode(_initialKubeconfig)).clusters[0]?.cluster?.server
    _initKubeconfigServerCaData = yaml.decode(base64.decode(_initialKubeconfig)).clusters[0]?.cluster?["certificate-authority-data"]
    _upboundSpaceHostFromKubeconfig = regex.replace(_initKubeconfigServerUrl, "https:\/\/([.\w-]+)(?:\/[.\w-]+){8}", "$1")
    _upboundBootstrapGroupFromKubeconfig = regex.replace(_initKubeconfigServerUrl, "https:\/(?:\/[.\w-]+){5}\/([.\w-]+)(?:\/[.\w-]+){3}", "$1")
    _upboundBootstrapCtpFromKubeconfig = regex.replace(_initKubeconfigServerUrl, "https:\/(?:\/[.\w-]+){7}\/([.\w-]+)(?:\/[.\w-]+)", "$1")
    _upboundOrgFromKubeconfig = yaml.decode(base64.decode(_initialKubeconfig)).contexts[0].context.extensions[0].extension.spec.cloud.organization

# Readiness-check for proceeding with read from status
_oxrStatusUpbound = oxr.status?.upbound
# Truthiness, not `!= Undefined`. On a fresh XR status.upbound is None, and in KCL both
# `None != Undefined` and `None?.field != Undefined` evaluate TRUE - so an Undefined-based
# guard lets an empty status through and the pipeline dies further down on the first
# `.bootstrapGroup`. These are all non-empty strings once set, so a plain truthy test is
# the only form that is correct for None, Undefined and "" alike.
_initReady = _oxrStatusUpbound?.org and \
    _oxrStatusUpbound?.bootstrapCtp and \
    _oxrStatusUpbound?.bootstrapGroup and \
    _oxrStatusUpbound?.spaceHost

_initItems = [
    sav1.Environment{
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
    kubernetesm.Object{
        metadata = {
            name = "{}-bootstrap-ctp-kubeconfig-observed".format(oxrMeta.name)
            annotations = {
                # Set explicitly rather than merging onto utils._metadata(): `|` REPLACES the
                # annotations map instead of merging into it, so adding krm.kcl.dev/ready on
                # top of it silently drops the composition resource name below - and main.k
                # looks this resource up by that name as ocds.observedCtpKubeconfig. Losing it
                # makes the lookup return nothing, so status.upbound stays {} and the
                # Environment never initialises.
                "krm.kcl.dev/composition-resource-name" = "observedCtpKubeconfig"
                # Gates the whole XR's readiness on initialisation having finished.
                #
                # Until the bootstrap kubeconfig is observed and status.upbound populated,
                # this observer is the ONLY composed resource - and it goes ready as soon as
                # the Secret it watches exists. function-auto-ready would then see "every
                # composed resource is ready" and report the Environment as Ready before a
                # single group, control plane, ProviderConfig or IAM resource had been
                # created. Anything polling Ready to know the environment is up gets a
                # false positive for that window.
                "krm.kcl.dev/ready" = "True" if _initReady else "False"
            }
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
                kind = "ProviderConfig"
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
            kubernetesm.Object{
                metadata = utils._metadata("ctp") | {
                    name = "{}-ctp".format(oxrMeta.name)
                }
                spec = {
                    readiness: {
                        policy: "DeriveFromObject"
                    }
                    managementPolicies = utils._managementPolicies(oxrSpec.parameters.deletionPolicy)
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
                        kind = "ProviderConfig"
                        name = "{}-group".format(envGroupName)
                    }
                }
            }

        if oxrSpec.parameters.upbound.createGroup:
            kubernetesm.Object{
                metadata = utils._metadata("envGroup") | {
                    name = envGroupName
                }
                spec = {
                    managementPolicies = utils._managementPolicies(oxrSpec.parameters.deletionPolicy)
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
                        kind = "ProviderConfig"
                        name = "{}-space".format(oxrMeta.name)
                    }
                }
            }
    ]
    if oxrSpec.parameters.upbound.createArgoSecret:
        # =========================================================================
        # Argo Server Secret Creation
        # =========================================================================
        # - Observe the Access Token (PersonalAccessToken or RobotToken)
        # - Create Argo Server Secret when Access Token is available

        _upboundItems += utils.observeSecret(utils.ObserveSecret{
            ctp = oxrMeta.name
            name = oxrSpec.parameters.upbound.tokenSecretRef.name
            namespace = oxrSpec.parameters.upbound.tokenSecretRef.namespace
            providerConfigName = "{}-ctp".format(_oxrStatusUpbound.bootstrapCtp)
            resourceName = "observed-access-token"
        })

        _accessToken = base64.decode(ocds["observed-access-token"]?.Resource?.status?.atProvider?.manifest?.data?.token)
        if _accessToken:
            _upboundItems += argo.argoServerSecret(argo.ArgoServerSecret{
                accessToken: _accessToken
                org = _oxrStatusUpbound.org
                group = envGroupName
                ctp = oxrMeta.name
                providerConfigName: "{}-ctp".format(_oxrStatusUpbound.bootstrapCtp)
                serverCaData: _initKubeconfigServerCaData
                spaceHost = _oxrStatusUpbound.spaceHost
            })

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

    # Not gated on createGroup. Everything the composition places *inside* the environment
    # group goes through this ProviderConfig - the ControlPlane above and the SharedAWSSecret
    # below both name it - and that is just as true when somebody else created the group. Only
    # the group object itself, and the space-level ProviderConfig that creates it, belong
    # behind createGroup.
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
            _awsItems += [sav1.SharedAWSSecret{
                metadata = utils._metadata("sharedAWSSecret") | {
                    name = "{}-shared-secret".format(oxrMeta.name)
                }
                spec = {
                    parameters = {
                        deletionPolicy = oxrSpec.parameters.deletionPolicy
                        aws = {
                            accountId = oxrSpec.parameters.aws.accountId
                            region = oxrSpec.parameters.aws.region
                            namePrefix = "{}-{}-{}".format(_oxrStatusUpbound.org, envGroupName, oxrMeta.name)
                            if oxrSpec.parameters.aws?.sharedSecret?.secretsManagerSecret:
                                secretsManagerSecret = {
                                    if oxrSpec.parameters.aws.sharedSecret.secretsManagerSecret?.arn:
                                        arn = oxrSpec.parameters.aws.sharedSecret.secretsManagerSecret.arn
                                    if oxrSpec.parameters.aws.sharedSecret.secretsManagerSecret?.name:
                                        name = oxrSpec.parameters.aws.sharedSecret.secretsManagerSecret.name
                                    if oxrSpec.parameters.aws.sharedSecret.secretsManagerSecret?.create != Undefined:
                                        create = oxrSpec.parameters.aws.sharedSecret.secretsManagerSecret.create
                                }
                            providerConfigRef = {
                                name = envGroupName
                            }
                        }
                        upbound = {
                            group = envGroupName
                            controlPlane = oxrMeta.name
                            providerConfigRef = {
                                name = "{}-group".format(envGroupName)
                            }
                        }
                        if oxrSpec.parameters.aws?.sharedSecret:
                            externalSecret = {
                                if oxrSpec.parameters.aws.sharedSecret.externalSecret?.name:
                                    name = oxrSpec.parameters.aws.sharedSecret.externalSecret.name
                                if oxrSpec.parameters.aws.sharedSecret.externalSecret?.namespace:
                                    namespace = oxrSpec.parameters.aws.sharedSecret.externalSecret.namespace
                                if oxrSpec.parameters.aws.sharedSecret.externalSecret?.spec:
                                    spec = {
                                        if oxrSpec.parameters.aws.sharedSecret.externalSecret.spec?.data:
                                            data = [{
                                                secretKey = item.secretKey
                                                remoteRef = {
                                                    key = item.remoteRef.key
                                                    if item.remoteRef?.property:
                                                        property = item.remoteRef.property
                                                    if item.remoteRef?.version:
                                                        version = item.remoteRef.version
                                                    if item.remoteRef?.metadataPolicy:
                                                        metadataPolicy = item.remoteRef.metadataPolicy
                                                    if item.remoteRef?.conversionStrategy:
                                                        conversionStrategy = item.remoteRef.conversionStrategy
                                                    if item.remoteRef?.decodingStrategy:
                                                        decodingStrategy = item.remoteRef.decodingStrategy
                                                }
                                                if item?.sourceRef:
                                                    sourceRef = {
                                                        if item.sourceRef?.generatorRef:
                                                            generatorRef = {
                                                                apiVersion = item.sourceRef.generatorRef.apiVersion
                                                                kind = item.sourceRef.generatorRef.kind
                                                                name = item.sourceRef.generatorRef.name
                                                            }
                                                    }
                                            } for item in oxrSpec.parameters.aws.sharedSecret.externalSecret.spec.data]
                                        if oxrSpec.parameters.aws.sharedSecret.externalSecret.spec?.target:
                                            target = {
                                                if oxrSpec.parameters.aws.sharedSecret.externalSecret.spec.target?.template:
                                                    template = {
                                                        if oxrSpec.parameters.aws.sharedSecret.externalSecret.spec.target.template?.data:
                                                            data = oxrSpec.parameters.aws.sharedSecret.externalSecret.spec.target.template.data
                                                        if oxrSpec.parameters.aws.sharedSecret.externalSecret.spec.target.template?.metadata:
                                                            metadata = {
                                                                if oxrSpec.parameters.aws.sharedSecret.externalSecret.spec.target.template.metadata?.labels:
                                                                    labels = oxrSpec.parameters.aws.sharedSecret.externalSecret.spec.target.template.metadata.labels
                                                            }
                                                    }
                                            }
                                    }
                            }
                    }
                }
            }]

# Return final resource list
items = _initItems + _upboundItems + _awsItems
