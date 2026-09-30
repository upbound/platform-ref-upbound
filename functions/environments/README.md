# environments

Composition function for `Environment` (`sa.upbound.io/v1`): an Upbound group holding one
control plane, wired to AWS.

- `function/fn.py` — initialisation from the bootstrap kubeconfig, then which resources apply
- `function/resources/` — one builder module per area: `kubernetes`, `argo`, `team_robot`,
  `secret_sync`, `aws`
- `function/common` — symlink to the project's shared `common/` package

Tests: `tests/test-environment*`. See the project README for how to build and run them.
