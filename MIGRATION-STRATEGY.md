# platform-ref-upbound: KCL → TypeScript Migration Strategy

Migrating from KCL composition functions (Upbound `up` devex) to TypeScript using the
new upstream Crossplane CLI devex (crossplane/cli#170).

## Tooling
- **CLI**: built from crossplane/cli PR #170 branch → `/Users/tobiaskasser/up/cli/_bin/crossplane`
- Commands: `crossplane project init|build`, `crossplane function generate -l typescript`,
  `crossplane dependency add`, `crossplane render`.
- SDK: `@crossplane-org/function-sdk-typescript`; schemas via `crossplane-models` (generated).

## Target format
- `upbound.yaml` (meta.dev.upbound.io) → `crossplane-project.yaml` (dev.crossplane.io/v1alpha1)
- `apis/` XRDs + compositions: kept (compositions repointed to new TS functionRefs)
- `functions/*` KCL → TypeScript (`src/function.ts`, package.json, tsconfig.json)
- `tests/*` KCL `CompositionTest` (run by `up test run`) → **render-based golden harness**
  (upstream CLI has no test runner). Each scenario rendered via `crossplane render` and
  diffed against the asserted resources extracted verbatim from the KCL tests.

## Functions (3) + Tests (7)
- `xupboundreposet` (smallest) — tests: test-xupboundreposet, test-xupboundreposet-repo-config
- `xsharedawssecret` (medium) — tests: test-xsharedawssecret, test-xsharedawssecret-with-data
- `xenvironments` (large; aws/argo/teamRobot/bootstrapSecretSync/pKubernetesHelper submodules)
  — tests: test-xenvironment, test-xenvironment-deletion-policy-delete,
  test-xenvironment-no-cloudprovider-resource

## Non-negotiables
- **Preserve test assertions exactly** — no weakening of expected resources. Re-expression
  into the render+diff harness must assert the same resources/fields the KCL tests do.
- Full coverage: all 7 scenarios ported and passing.
- Stop & report on any hard TS-experience failure (build/schema/render breakage).

## Phases
- **Phase 0 (spike, orchestrator)**: init upstream project on a branch; add deps; generate +
  port `xupboundreposet` TS function; resolve schema generation (incl. `sa.upbound.io` XRD
  types, `spaces.upbound.io` types, provider-upbound types); `project build`; render one
  scenario. Proves the full loop. **Gate: stop & report on hard error.**
- **Phase 1 (agents)**: port `xsharedawssecret` and `xenvironments` functions to TS in
  parallel (one powerful agent each), using Phase-0 patterns.
- **Phase 2 (agents)**: build the golden render harness; port all 7 test scenarios'
  assertions; per-function verification.
- **Phase 3 (orchestrator)**: run full suite, iterate to green. No test-logic changes.
