# sharedawssecret

Composition function for `SharedAWSSecret` (`sa.upbound.io/v1`): makes an AWS Secrets Manager
secret readable from an Upbound control plane, through an IAM user and access key, a
SharedSecretStore, and a SharedExternalSecret.

- `function/fn.py` — the function
- `function/common` — symlink to the project's shared `common/` package

Tests: `tests/test-sharedawssecret*`. See the project README for how to build and run them.
