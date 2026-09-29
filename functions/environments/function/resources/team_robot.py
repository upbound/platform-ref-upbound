"""A Team, a Robot with a Token, and the Team's admin rights on the environment group."""

from models.io.upbound.m.iam.robot import v1alpha1 as robotv1alpha1
from models.io.upbound.m.iam.robotteammembership import v1alpha1 as rtmv1alpha1
from models.io.upbound.m.iam.team import v1alpha1 as teamv1alpha1
from models.io.upbound.m.iam.token import v1alpha1 as tokenv1alpha1
from models.io.upbound.m.providerconfig import v1alpha1 as upbpcv1alpha1

from ..common.policy import ORPHAN
from .kubernetes import k8s_object
from .util import pc_ref


def team_with_robot(*, group, org, token_ref, observed_team_external_name, space_provider_config_name,
                    team_name_override=None, team_external_name=None, create_group_admin_binding=False) -> list:
    """A Team, a Robot in it with a Token, and optionally admin rights for the Team on the group."""
    upbound_pc = pc_ref(f"{group}-upbound")
    team_meta = {"name": f"{group}-team"}
    if team_external_name:
        team_meta["annotations"] = {"crossplane.io/external-name": team_external_name}
    items = [
        # Keyed by name: see the resources package docstring.
        (f"{group}-upbound", upbpcv1alpha1.ProviderConfig.model_validate({
            "metadata": {"name": f"{group}-upbound"},
            "spec": {
                "credentials": {"secretRef": token_ref, "source": "Secret"},
                "organization": org,
            },
        })),
        ("envRobot", robotv1alpha1.Robot.model_validate({
            "metadata": {"name": f"{group}-robot"},
            "spec": {
                "managementPolicies": ["*"],
                "forProvider": {"description": f"Robot for {group}", "name": f"{group}-bot", "owner": {"name": org}},
                "providerConfigRef": upbound_pc,
            },
        })),
        ("envRobotToken", tokenv1alpha1.Token.model_validate({
            "metadata": {"name": f"{group}-robot-token"},
            "spec": {
                "managementPolicies": ["*"],
                "forProvider": {"name": group, "owner": {"idRef": {"name": f"{group}-robot"}, "type": "robots"}},
                "providerConfigRef": upbound_pc,
                "writeConnectionSecretToRef": {"name": f"{group}-robot-token"},
            },
        })),
        ("envTeam", teamv1alpha1.Team.model_validate({
            "metadata": team_meta,
            "spec": {
                "managementPolicies": ORPHAN,
                "forProvider": {"name": team_name_override or f"{group}-team", "organizationName": org},
                "providerConfigRef": upbound_pc,
            },
        })),
        ("envRobotTeamMembership", rtmv1alpha1.RobotTeamMembership.model_validate({
            "metadata": {"name": f"{group}-robot-team-membership"},
            "spec": {
                "managementPolicies": ["*"],
                "forProvider": {"robotIdRef": {"name": f"{group}-robot"}, "teamIdRef": {"name": f"{group}-team"}},
                "providerConfigRef": upbound_pc,
            },
        })),
    ]
    if create_group_admin_binding:
        subject = {"kind": "UpboundTeam", "role": "admin"}
        # The Team's Upbound ID exists only once the Team has been created; until then the
        # subject has no name and the binding cannot apply yet. KCL behaved the same way.
        if observed_team_external_name:
            subject["name"] = observed_team_external_name
        items.append(("teamAdminBinding", k8s_object(f"{group}-admin-binding", {
            "managementPolicies": ["*"],
            "forProvider": {"manifest": {
                "apiVersion": "authorization.spaces.upbound.io/v1alpha1",
                "kind": "ObjectRoleBinding",
                "metadata": {"name": f"{group}-admin-binding", "namespace": group},
                "spec": {
                    "object": {"apiGroup": "core", "resource": "namespaces", "name": group},
                    "subjects": [subject],
                },
            }},
            "providerConfigRef": pc_ref(space_provider_config_name),
        })))
    return items
