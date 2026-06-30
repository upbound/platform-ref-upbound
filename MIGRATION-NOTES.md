# Migration Notes — proven patterns (Phase 0 spike)

## Toolchain (validated)
- CLI: `/Users/tobiaskasser/up/cli/_bin/crossplane` (built from PR #170 branch `pr-170`).
- Loop that works: `project init` → set `crossplane-project.yaml` deps → `function generate
  -l typescript` → port `src/function.ts` → `npm run build` (tsgo, local typecheck) →
  `crossplane render <xr> <composition>` **inside the project dir** (auto-wires embedded
  function + deps; no functions.yaml needed).

## crossplane-project.yaml dependency format (NOT the testing-guide shorthand)
```yaml
spec:
  schemas:
    languages: [typescript]
  dependencies:
  - type: xpkg
    xpkg:
      apiVersion: pkg.crossplane.io/v1
      kind: Provider          # or Function
      package: xpkg.upbound.io/upbound/provider-upbound
      version: '>=v0.9.1'
```

## Schema generation
- `function generate` only generates LOCAL XRD schemas. `project build` (or `render`)
  generates schemas from ALL dependency CRDs into `schemas/typescript/<group>/<version>/`.
- KCL `models.io.upbound.repository.v1alpha1` → TS `crossplane-models/repository.upbound.io/v1alpha1`.
  (group.version path; both `*.upbound.io` and `*.m.upbound.io` variants generated — use the
  non-`m` cluster-scoped ones to match the KCL.)

## Function authoring patterns
- `new <Model>({...})` from `crossplane-models/<group>/<version>` is type-checked on construction.
- DesiredComposed entries need `connectionDetails`/`ready`, so wrap via SDK `fromObject(...)`.
- **tsgo cannot see `toJSON()`** on generated models (dual `@kubernetes-models/base` resolution).
  Workaround: `fromObject(JSON.parse(JSON.stringify(model)) as Record<string, unknown>)`.
- The desired-map KEY becomes the `crossplane.io/composition-resource-name` annotation.
- Embedded manifests (e.g. `Object.spec.forProvider.manifest`, spaces.upbound.io types, raw
  `Usage`) can be built as PLAIN objects — no typed model needed, so `spaces` types don't
  require a schema dependency.

## Render runtime — pre-pull these images (render's pull deadline is short)
- `xpkg.crossplane.io/crossplane/crossplane:stable` (the render engine runs in Docker)
- each provider/function dependency image (e.g. provider-upbound:v1, function-auto-ready:v0.7.0)

## Test harness design (render + golden assert)
- `crossplane render <xrPath> <compositionPath> --observed-resources <dir>` reproduces the
  CompositionTest inputs (xrPath, compositionPath, observedResources).
- Assertion = each expected resource (from KCL `assertResources`) is a **semantic subset** of a
  rendered resource, matched by `composition-resource-name`.
- **Defaulting gap**: KCL `assertResources` include provider CRD defaults (`managementPolicies:
  ["*"]`, Permission `deletionPolicy: Delete`) that `crossplane render` does NOT emit (they're
  applied server-side at apply). Harness must normalize by applying CRD OpenAPI defaults before
  comparison — do NOT drop these assertions (preserve test logic).
