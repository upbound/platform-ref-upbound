"""AWS IAM resource names that fit IAM's length limit."""

IAM_NAME_MAX = 64


def simple_hash(s: str) -> str:
    """Position-weighted character sum, truncated to 8 digits.

    Not a cryptographic hash, and it does not need to be: it only has to be stable, because
    its output becomes part of an AWS resource name. It must stay identical to the KCL
    original it replaced - a different value renames, and so replaces, the IAM resource.
    """
    return str(abs(len(s) * 31 + sum(ord(c) * (i + 1) for i, c in enumerate(s))))[:8]


def truncate_iam_name(name: str, suffix: str) -> str:
    """Fit an IAM name into 64 characters, keeping the suffix and hashing the prefix."""
    if len(name) <= IAM_NAME_MAX:
        return name
    base = name[: len(name) - len(suffix)]
    prefix_space = IAM_NAME_MAX - len(suffix) - 8 - 1
    if prefix_space <= 0:
        return f"{simple_hash(base)}{suffix}"
    return f"{base[:prefix_space].rstrip('-')}-{simple_hash(base)}{suffix}"
