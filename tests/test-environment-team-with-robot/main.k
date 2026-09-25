"""
teamWithRobot - a Team, a Robot in it, a Token for the Robot, and, when the composition also
creates the group, an ObjectRoleBinding making the Team admin of that group.

This is the path solutions-gitops-prod's `ci` Environment runs, and it had no test at all.
The binding's subject is the Team's Upbound ID, which only exists once the Team has been
created, so the composition reads it off the observed Team's external name. The test
supplies that observed Team, which is what makes the binding's subject renderable.
"""

import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesm
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.iamm.v1alpha1 as iamv1alpha1
import models.io.upbound.sa.v1 as sav1

_status = {
    bootstrapCtp = "bootstrap"
    bootstrapGroup = "solutions-non-prod"
    org = "upbound"
    spaceHost = "upbound-aws-us-east-1.space.mxe.upbound.io"
}

_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-environment-team-with-robot"
        spec = {
            assertResources = [
                iamv1alpha1.Robot{
                    metadata.name = "solutions-non-prod-default-example-robot"
                    spec.forProvider = {
                        description = "Robot for solutions-non-prod-default-example"
                        name = "solutions-non-prod-default-example-bot"
                        owner.name = "upbound"
                    }
                }
                iamv1alpha1.Token{
                    metadata.name = "solutions-non-prod-default-example-robot-token"
                    spec.forProvider = {
                        name = "solutions-non-prod-default-example"
                        owner.type = "robots"
                    }
                }
                iamv1alpha1.Team{
                    metadata.name = "solutions-non-prod-default-example-team"
                    spec = {
                        # Teams are orphaned regardless of deletionPolicy.
                        managementPolicies = ["Create", "Observe", "Update", "LateInitialize"]
                        forProvider = {
                            name = "solutions-non-prod-default-example-team"
                            organizationName = "upbound"
                        }
                    }
                }
                iamv1alpha1.RobotTeamMembership{
                    metadata.name = "solutions-non-prod-default-example-robot-team-membership"
                    spec.forProvider = {
                        robotIdRef.name = "solutions-non-prod-default-example-robot"
                        teamIdRef.name = "solutions-non-prod-default-example-team"
                    }
                }
                # The binding's subject is the observed Team's Upbound ID.
                kubernetesm.Object{
                    metadata.name = "solutions-non-prod-default-example-admin-binding"
                    spec.forProvider.manifest = {
                        apiVersion = "authorization.spaces.upbound.io/v1alpha1"
                        kind = "ObjectRoleBinding"
                        spec.subjects = [{
                            kind = "UpboundTeam"
                            role = "admin"
                            name = "11111111-2222-3333-4444-555555555555"
                        }]
                    }
                }
            ]
            compositionPath = "apis/environments/composition.yaml"
            xrdPath = "apis/environments/definition.yaml"
            xr: sav1.Environment{
                metadata = {name = "example", namespace = "default"}
                spec.parameters.upbound = {
                    initKubeconfigSecretRef = {name = "init-kubeconfig"}
                    tokenSecretRef = {name = "upbound-token"}
                    createArgoSecret = False
                    teamWithRobot = {}
                }
                status.upbound = _status
            }
            observedResources = [
                iamv1alpha1.Team{
                    metadata = {
                        name = "solutions-non-prod-default-example-team"
                        namespace = "default"
                        annotations = {
                            "crossplane.io/composition-resource-name" = "envTeam"
                            "crossplane.io/external-name" = "11111111-2222-3333-4444-555555555555"
                        }
                    }
                    spec.forProvider = {
                        name = "solutions-non-prod-default-example-team"
                        organizationName = "upbound"
                    }
                }
            ]
            timeoutSeconds = 60
            validate = False
        }
    }
    # The shape of solutions-gitops-prod's `production-upbound-deploy`: adopt an existing Team
    # by ID and add a new Robot to it, inside a group somebody else manages.
    metav1alpha1.CompositionTest{
        metadata.name: "test-environment-team-external-name"
        spec = {
            assertResources = [
                iamv1alpha1.Team{
                    metadata = {
                        name = "solutions-non-prod-default-example-team"
                        annotations = {"crossplane.io/external-name" = "ae0e38df-fd52-4724-9c98-b8cd455d3d38"}
                    }
                    spec = {
                        managementPolicies = ["Create", "Observe", "Update", "LateInitialize"]
                        forProvider = {
                            name = "CI"
                            organizationName = "upbound"
                        }
                    }
                }
                iamv1alpha1.Robot{
                    metadata.name = "solutions-non-prod-default-example-robot"
                    spec.forProvider = {
                        description = "Robot for solutions-non-prod-default-example"
                        name = "solutions-non-prod-default-example-bot"
                        owner.name = "upbound"
                    }
                }
            ]
            compositionPath = "apis/environments/composition.yaml"
            xrdPath = "apis/environments/definition.yaml"
            xr: sav1.Environment{
                metadata = {name = "example", namespace = "default"}
                spec.parameters.upbound = {
                    initKubeconfigSecretRef = {name = "init-kubeconfig"}
                    tokenSecretRef = {name = "upbound-token"}
                    createArgoSecret = False
                    createGroup = False
                    createCtp = False
                    teamWithRobot = {
                        teamNameOverride = "CI"
                        teamExternalName = "ae0e38df-fd52-4724-9c98-b8cd455d3d38"
                    }
                }
                status.upbound = _status
            }
            timeoutSeconds = 60
            validate = False
        }
    }
]

items = _items
