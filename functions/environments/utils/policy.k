_managementPolicies = lambda deletionPolicy: str -> [str] {
    """
    Translates the XR-level deletionPolicy parameter into managementPolicies.

    Namespaced (.m.) managed resources have no deletionPolicy field in Crossplane v2 —
    managementPolicies is the only way to express "do not delete the external resource".
    The XR keeps the friendlier Delete/Orphan parameter and this maps it.

    Args:
        deletionPolicy: "Delete" or "Orphan"

    Returns:
        The managementPolicies list for a managed resource
    """
    ["*"] if deletionPolicy == "Delete" else ["Create", "Observe", "Update", "LateInitialize"]
}
