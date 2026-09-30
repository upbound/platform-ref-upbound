"""Builders for the resources an Environment composes.

Each builder returns a list of (composition key, resource) pairs; fn.py decides which apply.
The modules mirror the KCL modules this replaced - kubeconfigs and ProviderConfigs, the Argo CD
secret, Team and Robot, secret sync, and AWS - so a reader can hold the two side by side.

Composition keys matter beyond this package. A changed key makes Crossplane delete the resource
under the old one and create another, so every key here is the one the KCL version actually
produced - including the handful keyed by the resource's name instead. Those are marked.

Why some resources are keyed by name: the KCL carried the intended key in an annotation, then
merged more metadata over it. Where that merge wrote `annotations = {...}` - KCL's override
operator - it replaced the whole annotations map, the key went with it, and function-kcl fell
back to the resource name. Where it wrote `annotations: {...}` - the union operator - the key
survived. That is the only reason two identical-looking ProviderConfigs are keyed differently:
upboundreposet's used `:` and is keyed `providerConfigUpbound`; environments' used `=` and is
keyed by its name. It is not a bug to tidy away - the keys are load-bearing.
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
