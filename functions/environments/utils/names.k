# IAM name truncation. Mirrors functions/sharedawssecret/main.k: composition functions are
# separate packages and cannot import each other, so the two copies must be kept in step -
# and must stay byte-for-byte deterministic, because the result is the resource's AWS name.

_simpleHash = lambda s: str -> str {
    hash = len(s) * 31
    chars = [c for c in s]
    result = sum([ord(chars[i]) * (i + 1) for i in range(len(chars))])
    str(abs(hash + result))[:8]
}

# IAM caps role names at 64 characters. Over that, keep the suffix and replace the tail of
# the prefix with a hash of it, so distinct long names stay distinct.
_truncateIamName = lambda name: str, suffix: str -> str {
    maxLength = 64
    suffixLength = len(suffix)
    hashLength = 8
    separatorLength = 1
    prefixSpace = maxLength - suffixLength - hashLength - separatorLength
    baseName = name[:len(name) - suffixLength]
    hash = _simpleHash(baseName)

    name if len(name) <= maxLength else ("{}-{}{}".format(baseName[:prefixSpace].rstrip("-"), hash, suffix) if prefixSpace > 0 else "{}{}".format(hash, suffix))
}
