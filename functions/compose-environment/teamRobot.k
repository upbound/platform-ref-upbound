"""
Team and Robot Configuration Module

This module handles the creation of Upbound team and robot resources for environments. It creates:

1. An Upbound team that can be assigned permissions
2. A robot account with appropriate API tokens
3. Team membership for the robot
4. Role bindings for admin access to the environment group
5. Secrets containing token credentials for authentication
"""

import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
import models.io.upbound.iam.v1alpha1 as iamv1alpha1
import models.io.upbound.v1alpha1 as v1alpha1

schema TeamRobotTokenSecretRef:
    """
    Reference to the secret containing an Upbound token
    """
    name: str        # Name of the secret
    namespace: str   # Namespace of the secret
    key: str         # Key in the secret containing the token

schema TeamWithRobotInput:
    """
    Input parameters for creating a team with a robot account
    """
    group: str                       # Environment group name
    org: str                         # Upbound organization name
    secretDestProviderConfigName: str # Provider config for secret destination
    spaceProviderConfigName: str     # Provider config for Space operations
    tokenSecretRef: TeamRobotTokenSecretRef # Reference to existing token secret
    ocds: any
    teamNameOverride?: str
    teamExternalName?: str
    createGroupAdminBinding?: bool

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

teamWithRobot = lambda input: TeamWithRobotInput -> any {
    """
    Creates team and robot resources for Upbound Space environments.

    This function generates:
    1. An Upbound provider configuration using the supplied token
    2. A robot account in the organization
    3. An access token for the robot
    4. A secret with the robot's token in the environment
    5. A team within the Upbound organization
    6. Team membership for the robot
    7. Admin role binding for the team in the environment group
    """
    [
        # ProviderConfig provider-upbound
        v1alpha1.ProviderConfig{
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
        iamv1alpha1.Robot {
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
        iamv1alpha1.Token {
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
        # Team
        iamv1alpha1.Team {
            metadata: _metadata("envTeam") | {
                name = "{}-team".format(input.group)
                if input.teamExternalName:
                    annotations: {
                        "crossplane.io/external-name" = input.teamExternalName
                    }
            }
            spec = {
                deletionPolicy = "Orphan"
                forProvider = {
                    name = input.teamNameOverride or "{}-team".format(input.group)
                    organizationName = input.org
                }
                providerConfigRef = {
                    name = "{}-upbound".format(input.group)
                }
            }

        }
        # Robot team membership
        iamv1alpha1.RobotTeamMembership {
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
        if input.createGroupAdminBinding:
            kubernetesv1alpha2.Object{
                metadata: _metadata("teamAdminBinding") | {
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
                                        role = "admin"
                                        name = input.ocds.envTeam?.Resource?.metadata?.annotations?["crossplane.io/external-name"]
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
