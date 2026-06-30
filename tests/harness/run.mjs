#!/usr/bin/env node
// Composition test harness for the TypeScript migration.
//
// Replaces `up test run` (Upbound CompositionTest) with upstream
// `crossplane render` + golden-assert. Each golden file under
// tests/golden/<name>.yaml is a CompositionTest produced by `kcl run` over the
// original KCL test, so the assertions are preserved verbatim.
//
// For speed and stability it renders embedded functions via the **Development
// runtime**: each function is built locally (tsgo) and run as a process; render
// connects to it (host.docker.internal:PORT) instead of rebuilding a container
// per render (~1.5s vs ~3min). function-auto-ready runs as a Docker image.
//
// Test logic is NOT changed: every field in every assertResource must match.
// The only normalization is provider-CRD server-side defaults that
// `crossplane render` does not emit (managementPolicies, deletionPolicy); these
// are applied to the rendered managed resource before the subset check, never
// dropped.

import { execFileSync, spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, readdirSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createConnection } from 'node:net';
import yaml from 'js-yaml';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = resolve(__dirname, '..', '..');
const GOLDEN_DIR = join(PROJECT_ROOT, 'tests', 'golden');
const FUNCTIONS_DIR = join(PROJECT_ROOT, 'functions');
const SCHEMAS_DIR = join(PROJECT_ROOT, 'schemas', 'typescript');
const CROSSPLANE = process.env.CROSSPLANE_BIN || '/Users/tobiaskasser/up/cli/_bin/crossplane';
const AUTO_READY_PKG = process.env.AUTO_READY_PKG || 'xpkg.crossplane.io/crossplane-contrib/function-auto-ready:v0.7.0';
const AUTO_READY_REF = 'crossplane-contrib-function-auto-ready';
const PORT = Number(process.env.FN_PORT || 9443);

const MR_DEFAULTS = { managementPolicies: ['*'], deletionPolicy: 'Delete' };

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function sh(cmd, args, opts = {}) {
  return execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 64 * 1024 * 1024, ...opts });
}

function loadGolden(name) {
  const doc = yaml.load(readFileSync(join(GOLDEN_DIR, `${name}.yaml`), 'utf8'));
  const items = doc.items || [doc];
  const ct = items.find((i) => i && i.kind === 'CompositionTest');
  if (!ct) throw new Error(`${name}: no CompositionTest`);
  return ct.spec;
}

// Resolve the embedded function (dir + functionRef name) used by a composition.
function embeddedFunction(compositionPath) {
  const comp = yaml.load(readFileSync(compositionPath, 'utf8'));
  const steps = comp?.spec?.pipeline || [];
  const dirs = readdirSync(FUNCTIONS_DIR, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name);
  for (const step of steps) {
    const ref = step?.functionRef?.name;
    if (!ref || ref.includes('auto-ready')) continue;
    const dir = dirs.find((d) => ref.endsWith(d));
    if (dir) return { dir, ref };
  }
  throw new Error(`no embedded function found in ${compositionPath}`);
}

// Intentionally NOT installing node_modules into schemas/typescript: that dir
// is tarred verbatim by `crossplane project build` and symlinks in node_modules
// break it. Functions run with `node --preserve-symlinks` (see spawn below).

const built = new Set();
function buildFunction(dir) {
  if (built.has(dir)) return;
  const fnDir = join(FUNCTIONS_DIR, dir);
  if (!existsSync(join(fnDir, 'node_modules'))) sh('npm', ['install'], { cwd: fnDir });
  sh('npm', ['run', 'build'], { cwd: fnDir });
  built.add(dir);
}

async function waitForPort(port, timeoutMs = 8000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const ok = await new Promise((res) => {
      const s = createConnection({ host: '127.0.0.1', port }, () => { s.end(); res(true); });
      s.on('error', () => res(false));
    });
    if (ok) return true;
    await sleep(150);
  }
  return false;
}

function compositionResourceName(res) {
  return res?.metadata?.annotations?.['crossplane.io/composition-resource-name'];
}
function resourceKey(res) {
  const crn = compositionResourceName(res);
  if (crn) return `crn:${crn}`;
  if (res?.metadata?.name) return `${res.apiVersion}/${res.kind}/${res.metadata.name}`;
  if (res?.metadata?.generateName) return `${res.apiVersion}/${res.kind}/gen:${res.metadata.generateName}`;
  return `${res.apiVersion}/${res.kind}`;
}
function isManagedResource(res) {
  return res?.spec && typeof res.spec === 'object' && 'forProvider' in res.spec;
}
function withDefaults(rendered) {
  if (!isManagedResource(rendered)) return rendered;
  const out = structuredClone(rendered);
  if (out.spec.managementPolicies === undefined) out.spec.managementPolicies = MR_DEFAULTS.managementPolicies;
  if (out.spec.deletionPolicy === undefined) out.spec.deletionPolicy = MR_DEFAULTS.deletionPolicy;
  return out;
}
function subsetMismatches(expected, actual, path = '') {
  const out = [];
  if (Array.isArray(expected)) {
    if (!Array.isArray(actual)) { out.push(`${path}: expected array, got ${typeof actual}`); return out; }
    if (expected.length !== actual.length) out.push(`${path}: array length expected ${expected.length}, got ${actual.length}`);
    for (let i = 0; i < expected.length; i++) out.push(...subsetMismatches(expected[i], actual?.[i], `${path}[${i}]`));
    return out;
  }
  if (expected && typeof expected === 'object') {
    if (!actual || typeof actual !== 'object') { out.push(`${path}: expected object, got ${JSON.stringify(actual)}`); return out; }
    for (const k of Object.keys(expected)) out.push(...subsetMismatches(expected[k], actual[k], path ? `${path}.${k}` : k));
    return out;
  }
  if (expected !== actual) out.push(`${path}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  return out;
}

function writeFunctionsFile(file, fnRef) {
  const docs = [
    { apiVersion: 'pkg.crossplane.io/v1', kind: 'Function',
      metadata: { name: fnRef, annotations: { 'render.crossplane.io/runtime': 'Development', 'render.crossplane.io/runtime-development-target': `host.docker.internal:${PORT}` } },
      spec: { package: `xpkg.upbound.io/local/${fnRef}` } },
    { apiVersion: 'pkg.crossplane.io/v1', kind: 'Function',
      metadata: { name: AUTO_READY_REF }, spec: { package: AUTO_READY_PKG } },
  ];
  writeFileSync(file, docs.map((d) => yaml.dump(d)).join('---\n'));
}

function cleanupDockerNetworks() {
  try {
    const nets = sh('docker', ['network', 'ls', '--filter', 'name=crossplane-render', '-q']).trim();
    if (nets) for (const n of nets.split('\n')) try { sh('docker', ['network', 'rm', n]); } catch {}
  } catch {}
}

async function runScenario(name) {
  const spec = loadGolden(name);
  const compositionPath = join(PROJECT_ROOT, spec.compositionPath);
  const xrdPath = spec.xrdPath ? join(PROJECT_ROOT, spec.xrdPath) : null;
  const observed = spec.observedResources || [];
  const assertResources = spec.assertResources || [];
  const { dir, ref } = embeddedFunction(compositionPath);

  buildFunction(dir);

  const tmp = mkdtempSync(join(tmpdir(), `ct-${name}-`));
  let xrPath;
  if (spec.xrPath) xrPath = join(PROJECT_ROOT, spec.xrPath);
  else if (spec.xr) { xrPath = join(tmp, 'xr.yaml'); writeFileSync(xrPath, yaml.dump(spec.xr)); }
  else { rmSync(tmp, { recursive: true, force: true }); return { name, ok: false, error: 'no xrPath or inline xr' }; }

  const fnFile = join(tmp, 'functions.yaml');
  writeFunctionsFile(fnFile, ref);

  // Determine the composite (XR) kind so we can exclude it from observed
  // resources. `up test` treats the xrPath XR as the authoritative observed
  // composite; `crossplane render`, however, PROMOTES any composite-kind entry
  // found in --observed-resources into req.observed.composite (clobbering the
  // XR's spec/status) and drops the rest of observed.resources. Observed
  // *composed* resources never include the composite itself, so filtering the
  // composite kind out faithfully reproduces `up test` semantics without
  // altering any assertion.
  const xrDoc = yaml.load(readFileSync(xrPath, 'utf8'));
  const compositeKind = xrDoc?.kind;
  const observedComposed = observed.filter((r) => r && r.kind !== compositeKind);

  const args = ['render', xrPath, compositionPath, fnFile, '--include-full-xr', '--timeout=3m'];
  if (xrdPath) args.push('--xrd', xrdPath);
  if (observedComposed.length) { const o = join(tmp, 'observed.yaml'); writeFileSync(o, observedComposed.map((r) => yaml.dump(r)).join('---\n')); args.push('-o', o); }

  // --preserve-symlinks: the function's `crossplane-models` is a symlink to
  // schemas/typescript; this makes node resolve its (@kubernetes-models/*) deps
  // from the function's own node_modules instead of the real schemas path, so we
  // never have to install node_modules into schemas/ (which would break
  // `crossplane project build`'s tar-schemas step on the symlinks).
  const proc = spawn('node', ['--preserve-symlinks', join(FUNCTIONS_DIR, dir, 'dist', 'main.js'), '--insecure', '--address', `0.0.0.0:${PORT}`], { stdio: ['ignore', 'pipe', 'pipe'] });
  let fnErr = '';
  proc.stderr.on('data', (d) => { fnErr += d.toString(); });
  proc.stdout.on('data', (d) => { fnErr += d.toString(); });

  let result;
  try {
    if (!(await waitForPort(PORT))) throw new Error(`function process did not listen on :${PORT}\n${fnErr.slice(-800)}`);
    let out;
    try {
      out = sh(CROSSPLANE, args, { cwd: PROJECT_ROOT });
    } catch (e) {
      throw new Error(`render failed:\n${(e.stderr || e.message).split('\n').slice(-8).join('\n')}`);
    }
    const rendered = yaml.loadAll(out).filter(Boolean);
    const byKey = new Map();
    for (const r of rendered) byKey.set(resourceKey(r), r);

    const failures = [];
    for (const exp of assertResources) {
      const key = resourceKey(exp);
      let actual = byKey.get(key);
      if (!actual && exp?.metadata?.name) actual = rendered.find((r) => r.kind === exp.kind && r.metadata?.name === exp.metadata.name);
      if (!actual) { failures.push(`MISSING key=${key} (kind=${exp.kind})`); continue; }
      const mism = subsetMismatches(exp, withDefaults(actual));
      if (mism.length) failures.push(`MISMATCH key=${key} (kind=${exp.kind}):\n      ${mism.slice(0, 30).join('\n      ')}`);
    }
    const assertedKeys = new Set(assertResources.map(resourceKey));
    const extra = rendered
      .filter((r) => !['XEnvironment', 'XSharedAWSSecret', 'XUpboundRepoSet'].includes(r.kind))
      .filter((r) => !assertedKeys.has(resourceKey(r))).map(resourceKey);
    result = { name, ok: failures.length === 0, failures, expected: assertResources.length, rendered: rendered.length, extra };
  } catch (e) {
    result = { name, ok: false, error: e.message };
  } finally {
    proc.kill('SIGTERM');
    rmSync(tmp, { recursive: true, force: true });
    cleanupDockerNetworks();
  }
  return result;
}

async function main() {
  const scenarios = process.argv.slice(2).length
    ? process.argv.slice(2)
    : readdirSync(GOLDEN_DIR).filter((f) => f.endsWith('.yaml')).map((f) => f.replace(/\.yaml$/, '')).sort();

  let allOk = true;
  for (const s of scenarios) {
    let res;
    try { res = await runScenario(s); } catch (e) { res = { name: s, ok: false, error: e.message }; }
    if (res.ok) {
      console.log(`✓ ${s}  (asserted ${res.expected}, rendered ${res.rendered}${res.extra?.length ? `, extra ${res.extra.length}` : ''})`);
    } else {
      allOk = false;
      console.log(`✗ ${s}`);
      if (res.error) console.log(`    ${res.error.split('\n').join('\n    ')}`);
      for (const f of (res.failures || [])) console.log(`    ${f}`);
      if (res.extra?.length) console.log(`    (unasserted rendered: ${res.extra.join(', ')})`);
    }
  }
  process.exit(allOk ? 0 : 1);
}

main();
