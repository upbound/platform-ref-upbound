"""teamWithRobot - a Team, a Robot in it, a Token for the Robot, and, when the composition also
creates the group, an ObjectRoleBinding making the Team admin of that group.

This is the path solutions-gitops-prod's `ci` Environment runs, and it had no test at all.
The binding's subject is the Team's Upbound ID, which only exists once the Team has been
created, so the composition reads it off the observed Team's external name. The test
supplies that observed Team, which is what makes the binding's subject renderable.
"""

import yaml
from models.io.k8s.apimachinery.pkg.apis.meta import v1 as k8s
from models.io.upbound.dev.meta.compositiontest import v1alpha1 as compositiontest

PREFIX = "solutions-non-prod-default-example"
TEAM = f"{PREFIX}-team"
ROBOT = f"{PREFIX}-robot"
TEAM_ID = "11111111-2222-3333-4444-555555555555"
ORPHAN = ["Create", "Observe", "Update", "LateInitialize"]

STATUS = {
    "bootstrapCtp": "bootstrap",
    "bootstrapGroup": "solutions-non-prod",
    "org": "upbound",
    "spaceHost": "upbound-aws-us-east-1.space.mxe.upbound.io",
}

ROBOT_RESOURCE = {
    "apiVersion": "iam.m.upbound.io/v1alpha1",
    "kind": "Robot",
    "metadata": {"name": ROBOT},
    "spec": {
        "forProvider": {
            "description": f"Robot for {PREFIX}",
            "name": f"{PREFIX}-bot",
            "owner": {"name": "upbound"},
        },
        "managementPolicies": ["*"],
    },
}


def environment(upbound: dict) -> dict:
    """The Environment XR under test; `upbound` is spec.parameters.upbound."""
    return {
        "apiVersion": "sa.upbound.io/v1",
        "kind": "Environment",
        "metadata": {"name": "example", "namespace": "default"},
        "spec": {
            "parameters": {
                "deletionPolicy": "Orphan",
                "upbound": {
                    "initKubeconfigSecretRef": {"key": "kubeconfig", "name": "init-kubeconfig", "namespace": "default"},
                    "tokenSecretRef": {"key": "token", "name": "upbound-token", "namespace": "default"},
                    "createArgoSecret": False,
                    "createCtp": True,
                    "createGroup": True,
                    "initProviderConfigName": "bootstrap-ctp",
                    **upbound,
                },
            },
        },
        "status": {"upbound": STATUS},
    }


tests = [
    compositiontest.CompositionTest(
        metadata=k8s.ObjectMeta(name="test-environment-team-with-robot"),
        spec=compositiontest.Spec(
            assertResources=[
                ROBOT_RESOURCE,
                {
                    "apiVersion": "iam.m.upbound.io/v1alpha1",
                    "kind": "Token",
                    "metadata": {"name": f"{ROBOT}-token"},
                    "spec": {
                        "forProvider": {"name": PREFIX, "owner": {"type": "robots"}},
                        "managementPolicies": ["*"],
                    },
                },
                {
                    "apiVersion": "iam.m.upbound.io/v1alpha1",
                    "kind": "Team",
                    "metadata": {"name": TEAM},
                    "spec": {
                        # Teams are orphaned regardless of deletionPolicy.
                        "managementPolicies": ORPHAN,
                        "forProvider": {"name": TEAM, "organizationName": "upbound"},
                    },
                },
                {
                    "apiVersion": "iam.m.upbound.io/v1alpha1",
                    "kind": "RobotTeamMembership",
                    "metadata": {"name": f"{ROBOT}-team-membership"},
                    "spec": {
                        "forProvider": {"robotIdRef": {"name": ROBOT}, "teamIdRef": {"name": TEAM}},
                        "managementPolicies": ["*"],
                    },
                },
                # The binding's subject is the observed Team's Upbound ID.
                {
                    "apiVersion": "kubernetes.m.crossplane.io/v1alpha1",
                    "kind": "Object",
                    "metadata": {"name": f"{PREFIX}-admin-binding"},
                    "spec": {
                        "forProvider": {
                            "deletionPropagationPolicy": "Background",
                            "manifest": {
                                "apiVersion": "authorization.spaces.upbound.io/v1alpha1",
                                "kind": "ObjectRoleBinding",
                                "spec": {"subjects": [{"kind": "UpboundTeam", "role": "admin", "name": TEAM_ID}]},
                            },
                        },
                        "managementPolicies": ["*"],
                        "watch": False,
                    },
                },
            ],
            compositionPath="apis/environments/composition.yaml",
            xrdPath="apis/environments/definition.yaml",
            xr=environment({"teamWithRobot": {}}),
            observedResources=[
                {
                    "apiVersion": "iam.m.upbound.io/v1alpha1",
                    "kind": "Team",
                    "metadata": {
                        "name": TEAM,
                        "namespace": "default",
                        "annotations": {
                            "crossplane.io/composition-resource-name": "envTeam",
                            "crossplane.io/external-name": TEAM_ID,
                        },
                    },
                    "spec": {
                        "forProvider": {"name": TEAM, "organizationName": "upbound"},
                        "managementPolicies": ["*"],
                    },
                },
            ],
            timeoutSeconds=60,
            validate=False,
        ),
    ),
    # The shape of solutions-gitops-prod's `production-upbound-deploy`: adopt an existing Team
    # by ID and add a new Robot to it, inside a group somebody else manages.
    compositiontest.CompositionTest(
        metadata=k8s.ObjectMeta(name="test-environment-team-external-name"),
        spec=compositiontest.Spec(
            assertResources=[
                {
                    "apiVersion": "iam.m.upbound.io/v1alpha1",
                    "kind": "Team",
                    "metadata": {
                        "name": TEAM,
                        "annotations": {"crossplane.io/external-name": "ae0e38df-fd52-4724-9c98-b8cd455d3d38"},
                    },
                    "spec": {
                        "managementPolicies": ORPHAN,
                        "forProvider": {"name": "CI", "organizationName": "upbound"},
                    },
                },
                ROBOT_RESOURCE,
            ],
            compositionPath="apis/environments/composition.yaml",
            xrdPath="apis/environments/definition.yaml",
            xr=environment(
                {
                    "createGroup": False,
                    "createCtp": False,
                    "teamWithRobot": {
                        "teamNameOverride": "CI",
                        "teamExternalName": "ae0e38df-fd52-4724-9c98-b8cd455d3d38",
                    },
                }
            ),
            timeoutSeconds=60,
            validate=False,
        ),
    ),
]

# The test runner expects an "items" array, one entry per test.
print(yaml.dump({"items": [t.model_dump(by_alias=True, exclude_none=True) for t in tests]}))
