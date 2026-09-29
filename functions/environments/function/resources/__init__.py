"""Builders for the resources an Environment composes.

Each builder returns a list of (composition key, resource) pairs; fn.py decides which apply.
The modules mirror the KCL modules this replaced - kubeconfigs and ProviderConfigs, the Argo CD
secret, Team and Robot, secret sync, and AWS - so a reader can hold the two side by side.

Composition keys matter beyond this package. A changed key makes Crossplane delete the resource
under the old one and create another, so every key here is the one the KCL version actually
produced - including the handful where KCL fell back to the resource's name because merging
metadata had replaced the annotation carrying the intended key. Those are marked.
"""

from ..common.policy import management_policies
from .argo import argo_server_secret
from .aws import aws_provider_config, crossplane_role
from .kubernetes import k8s_object, observe_secret, upbound_provider_config
from .secret_sync import synced_secret
from .team_robot import team_with_robot
from .util import pc_ref

__all__ = [
    "argo_server_secret",
    "aws_provider_config",
    "crossplane_role",
    "k8s_object",
    "management_policies",
    "observe_secret",
    "pc_ref",
    "synced_secret",
    "team_with_robot",
    "upbound_provider_config",
]
