# imported with `kcl import -m crd crd.yaml` from kube-crd
# and fixed k8s imoprt to `import ..k8s.apimachinery.pkg.apis.meta.v1`
import providerUpboundModels.v1alpha1 as pupboundv1alpha1

import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2

schema TeamRobotTokenSecretRef:
    name: str
    namespace: str
    key: str

schema TeamWithRobotInput:
    group: str
    org: str
    secretDestProviderConfigName: str
    spaceProviderConfigName: str
    tokenSecretRef: TeamRobotTokenSecretRef

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

teamWithRobot = lambda input: TeamWithRobotInput -> any {
    [
        # ProviderConfig provider-upbound
        pupboundv1alpha1.ProviderConfig{
            metadata =  _metadata("providerConfigUpbound") | {
                annotations = {
                  "krm.kcl.dev/ready" = "True"
                }
                name = "{}-upbound".format(input.group)
            }
            spec = {
                credentials = {
                    secretRef = {
                        name = input.tokenSecretRef.name
                        namespace = input.tokenSecretRef.namespace
                        key = input.tokenSecretRef.key
                    }
                    source = "Secret"
                }
                organization = input.org
            }
        }

        # Robot
        pupboundv1alpha1.Robot {
            metadata = _metadata("envRobot") | {
                name = "{}-robot".format(input.group)
            }
            spec = {
                forProvider = {
                    description = "Robot for {}".format(input.group)
                    name = "{}-bot".format(input.group)
                    owner = {
                        name = input.org
                    }
                }
                providerConfigRef = {
                    name = "{}-upbound".format(input.group)
                }
            }

        }
        # Robot Token
        pupboundv1alpha1.Token {
            metadata = _metadata("envRobotToken") | {
                name = "{}-robot-token".format(input.group)
            }
            spec = {
                forProvider = {
                    name = input.group
                    owner =  {
                        idRef = {
                            name = "{}-robot".format(input.group)
                        }
                        type = "robots"
                    }
                }
                providerConfigRef = {
                    name = "{}-upbound".format(input.group)
                }
                writeConnectionSecretToRef = {
                    name = "{}-robot-token".format(input.group)
                    namespace = "default"
                }
            }
        }
        # Copy robot token to env ctp
        kubernetesv1alpha2.Object {
            metadata = _metadata("robotTokenEnvCtpSecret") | {
                name = "{}-rt-secret".format(input.group)
            }
            spec = {
                forProvider = {
                    manifest = {
                        apiVersion = "v1"
                        kind = "Secret"
                        metadata = {
                            namespace = "default"
                        }
                    }
                }
                providerConfigRef = {
                    name = input.secretDestProviderConfigName
                }
                references = [
                    {
                        patchesFrom = {
                            apiVersion = "v1"
                            kind = "Secret"
                            name = "{}-robot-token".format(input.group)
                            namespace = "default"
                            fieldPath = "data.token"
                        }
                        toFieldPath = "data.token"
                    }
                ]
            }
        }
        # Team
        pupboundv1alpha1.Team {
            metadata = _metadata("envTeam") | {
                name = "{}-team".format(input.group)
            }
            spec = {
                forProvider = {
                    name = input.group
                    organizationName = input.org
                }
                providerConfigRef = {
                    name = "{}-upbound".format(input.group)
                }
            }

        }
        # Robot team membership
        pupboundv1alpha1.RobotTeamMembership {
            metadata = _metadata("envRobotTeamMembership") | {
                name = "{}-robot-team-membership".format(input.group)
            }
            spec = {
                forProvider = {
                    robotIdRef = {
                        name = "{}-robot".format(input.group)
                    }
                    teamIdRef = {
                        name = "{}-team".format(input.group)
                    }
                }
                providerConfigRef = {
                    name = "{}-upbound".format(input.group)
                }
            }

        }
        # Grant admin rights on group to team
        kubernetesv1alpha2.Object{
            metadata = _metadata("teamAdminBinding") | {
                name = "{}-admin-binding".format(input.group)
            }
            spec = {
                forProvider = {
                    manifest = {
                        apiVersion = "authorization.spaces.upbound.io/v1alpha1"
                        kind = "ObjectRoleBinding"
                        metadata = {
                            name = "{}-admin-binding".format(input.group)
                            namespace = input.group
                        }
                        spec = {
                            object = {
                                apiGroup = "core"
                                resource = "namespaces"
                                name = input.group
                            }
                            subjects = [
                                {
                                    kind = "UpboundTeam"
                                    # group name and team name are the same
                                    name = input.group
                                    role = "admin"
                                }
                            ]
                        }
                    }
                }
                providerConfigRef = {
                    name = input.spaceProviderConfigName
                }
            }
        }
    ]
}
