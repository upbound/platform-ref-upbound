"""Copying Secrets from the bootstrap control plane into the environment."""

from .kubernetes import k8s_object
from .util import pc_ref


def synced_secret(*, source_ref, dest_ref, provider_config_name) -> list:
    """Copy a Secret from the bootstrap control plane into the environment's control plane."""
    key = f"{source_ref['namespace']}-{source_ref['name']}-to-{dest_ref['namespace']}-{dest_ref['name']}-syncedSecret"
    return [(key, k8s_object(None, {
        "managementPolicies": ["*"],
        "forProvider": {"manifest": {
            "apiVersion": "v1",
            "kind": "Secret",
            "metadata": {"name": dest_ref["name"], "namespace": dest_ref["namespace"]},
        }},
        "providerConfigRef": pc_ref(provider_config_name),
        "references": [{
            "patchesFrom": {
                "apiVersion": "v1",
                "kind": "Secret",
                "name": source_ref["name"],
                "namespace": source_ref["namespace"],
                "fieldPath": "data",
            },
            "toFieldPath": "data",
        }],
    }))]
