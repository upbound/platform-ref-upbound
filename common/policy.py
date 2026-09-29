"""managementPolicies for the XR-level deletionPolicy parameter."""

# Orphan on delete. Namespaced (.m.) managed resources have no deletionPolicy; leaving
# "Delete" out of managementPolicies is the only way to keep the external resource.
ORPHAN = ["Create", "Observe", "Update", "LateInitialize"]


def management_policies(deletion_policy: str) -> list[str]:
    """Translate the XR's Delete/Orphan parameter into managementPolicies."""
    return ["*"] if deletion_policy == "Delete" else ORPHAN
