"""Output the KCL implementation produced that Python does not produce on its own.

This function replaced a KCL one, and keeps its rendered output identical - the composition
tests compare it byte for byte in places, and a changed field on a live control plane is a
changed resource. Two KCL behaviours need reproducing to get there:

- `str()` of a dict, which KCL renders in its own syntax rather than as YAML or JSON. The
  kubeconfig Secrets were written that way, and their bytes are what provider-kubernetes
  reads - it happens to parse as a YAML flow mapping.
- defaults KCL's typed models materialise into every resource, whether or not the function
  set them.
"""

# provider-kubernetes Object defaults KCL emitted on every Object.
OBJECT_FOR_PROVIDER_DEFAULTS = {"deletionPropagationPolicy": "Background"}
OBJECT_SPEC_DEFAULTS = {"watch": False}


def kcl_str(value, in_list: bool = False) -> str:
    """Render a value the way KCL's str() does.

    Dict keys and dict values that are strings are single-quoted; a string that is a list
    element is NOT quoted - so a list of strings renders as `[organization, token]`. Booleans
    are True/False. Insertion order is kept.
    """
    if isinstance(value, dict):
        return "{" + ", ".join(f"'{k}': {kcl_str(v)}" for k, v in value.items()) + "}"
    if isinstance(value, list):
        return "[" + ", ".join(kcl_str(v, in_list=True) for v in value) + "]"
    if isinstance(value, bool):
        return "True" if value else "False"
    if isinstance(value, str):
        return value if in_list else f"'{value}'"
    return str(value)


def object_spec(spec: dict) -> dict:
    """An Object spec with the provider-kubernetes defaults KCL materialised."""
    spec = {**OBJECT_SPEC_DEFAULTS, **spec}
    spec["forProvider"] = {**OBJECT_FOR_PROVIDER_DEFAULTS, **spec["forProvider"]}
    return spec
