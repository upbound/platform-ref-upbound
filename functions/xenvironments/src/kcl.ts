// Replicates KCL builtin string/serialization behaviours needed for a faithful port.

/**
 * Replicates KCL's `str(<dict/list/...>)` rendering as observed in the golden
 * kubeconfig output:
 * - dicts: keys sorted alphabetically, keys quoted with single quotes,
 *   rendered as `{'k': v, ...}`
 * - string values used as dict values are single-quoted
 * - string elements directly inside a list are rendered WITHOUT quotes
 * - booleans render as Python-style `True` / `False`
 * - empty dict renders as `{}`
 */
export function kclStr(v: unknown, inListScalar = false): string {
  if (v === null || v === undefined) {
    return 'None';
  }
  if (Array.isArray(v)) {
    return '[' + v.map((e) => kclStr(e, true)).join(', ') + ']';
  }
  if (typeof v === 'object') {
    const obj = v as Record<string, unknown>;
    const keys = Object.keys(obj).sort();
    return '{' + keys.map((k) => `'${k}': ${kclStr(obj[k])}`).join(', ') + '}';
  }
  if (typeof v === 'boolean') {
    return v ? 'True' : 'False';
  }
  if (typeof v === 'string') {
    return inListScalar ? v : `'${v}'`;
  }
  return String(v);
}

export function b64decode(s: string): string {
  return Buffer.from(s, 'base64').toString('utf8');
}

/**
 * Replicates KCL's `json.encode(...)`: standard JSON but with a space after
 * every `:` and `,` separator (Python json.dumps default), preserving the
 * insertion order of object keys.
 */
export function jsonEncode(v: unknown): string {
  if (v === null || v === undefined) return 'null';
  if (Array.isArray(v)) {
    return '[' + v.map((e) => jsonEncode(e)).join(', ') + ']';
  }
  if (typeof v === 'object') {
    const obj = v as Record<string, unknown>;
    return (
      '{' +
      Object.keys(obj)
        .map((k) => `${JSON.stringify(k)}: ${jsonEncode(obj[k])}`)
        .join(', ') +
      '}'
    );
  }
  return JSON.stringify(v);
}
