"""Reading untyped request data."""


def dig(d, *path):
    """Walk nested dicts, returning None at the first missing level."""
    for key in path:
        if not isinstance(d, dict):
            return None
        d = d.get(key)
    return d
