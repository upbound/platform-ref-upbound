"""Small helpers every resource module uses."""


def pc_ref(name: str) -> dict:
    return {"kind": "ProviderConfig", "name": name}
