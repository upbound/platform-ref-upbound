"""SharedAWSSecret: the IAM user that reads a Secrets Manager secret, and its Spaces fan-out.

Six scenarios: the default namePrefix naming, an explicit secretsManagerSecret.name override,
create=false, recoveryWindowInDays, a name long enough to trigger hash truncation, and an XR
that omits the secretsManagerSecret block entirely.
"""

import json

import yaml
from models.io.k8s.apimachinery.pkg.apis.meta import v1 as k8s
from models.io.upbound.dev.meta.compositiontest import v1alpha1 as compositiontest

ORPHAN = ["Create", "Observe", "Update", "LateInitialize"]
ACCESS_KEY_SECRET = "example-env-secrets-read-access-key"
AWS_PROVIDER_CONFIG = {"kind": "ProviderConfig", "name": "example-env"}
GROUP_PROVIDER_CONFIG = {"kind": "ProviderConfig", "name": "example-env-group"}
LONG_SECRET_NAME = (
    "this-is-a-very-long-secret-name-that-will-exceed-the-64-character-limit"
    "-for-iam-resources-and-should-trigger-hash-truncation"
)


def kubernetes_object(name: str, manifest: dict, **spec) -> dict:
    return {
        "apiVersion": "kubernetes.m.crossplane.io/v1alpha1",
        "kind": "Object",
        "metadata": {"name": name},
        "spec": {
            # deletionPropagationPolicy is the schema default the KCL model materialised.
            "forProvider": {"deletionPropagationPolicy": "Background", "manifest": manifest},
            "managementPolicies": ORPHAN,
            "providerConfigRef": GROUP_PROVIDER_CONFIG,
            **spec,
            "watch": False,
        },
    }


# Common resources that are the same across all test scenarios (only the secret copy)
COMMON_RESOURCES = [
    kubernetes_object(
        ACCESS_KEY_SECRET,
        {
            "apiVersion": "v1",
            "kind": "Secret",
            "metadata": {"name": ACCESS_KEY_SECRET, "namespace": "example-env"},
        },
        references=[
            {
                "patchesFrom": {
                    "apiVersion": "v1",
                    "fieldPath": "data",
                    "kind": "Secret",
                    "name": ACCESS_KEY_SECRET,
                    "namespace": "default",
                },
                "toFieldPath": "data",
            }
        ],
    )
]


def iam_resource(kind: str, name: str, for_provider: dict, **spec) -> dict:
    return {
        "apiVersion": "iam.aws.m.upbound.io/v1beta1",
        "kind": kind,
        "metadata": {"name": name},
        "spec": {
            "forProvider": for_provider,
            "managementPolicies": ORPHAN,
            "providerConfigRef": AWS_PROVIDER_CONFIG,
            **spec,
        },
    }


def iam_resources(name: str, secret: str) -> list[dict]:
    """The Policy, UserPolicyAttachment, AccessKey and User that grant read access to secret."""
    policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "secretsmanager:GetSecretValue",
                    "secretsmanager:DescribeSecret",
                    "secretsmanager:ListSecretVersionIds",
                ],
                "Resource": [f"arn:aws:secretsmanager:us-east-1:123456789012:secret:{secret}-*"],
            }
        ],
    }
    return [
        iam_resource("Policy", name, {"policy": json.dumps(policy)}),
        iam_resource(
            "UserPolicyAttachment",
            name,
            {"policyArnSelector": {"matchControllerRef": True}, "userSelector": {"matchControllerRef": True}},
        ),
        iam_resource(
            "AccessKey",
            name,
            {"userSelector": {"matchControllerRef": True}},
            writeConnectionSecretToRef={"name": ACCESS_KEY_SECRET},
        ),
        iam_resource("User", name, {}),
    ]


# Static IAM resources for different test cases
IAM_RESOURCES_DEFAULT = iam_resources("example-shared-secret-example-env-config-secrets-read", "example-env-config")
IAM_RESOURCES_OVERRIDE = iam_resources("example-shared-secret-example-config-secrets-read", "example-config")
IAM_RESOURCES_NO_CREATE = iam_resources("example-shared-secret-existing-secret-secrets-read", "existing-secret")


# Static shared resources
def shared_secret_store(namespace: str) -> dict:
    return kubernetes_object(
        "example-ctp-sss",
        {
            "apiVersion": "spaces.upbound.io/v1alpha1",
            "kind": "SharedSecretStore",
            "metadata": {"name": "example-ctp", "namespace": "example-env"},
            "spec": {
                "controlPlaneSelector": {"names": ["example-ctp"]},
                "namespaceSelector": {"names": [namespace]},
                "provider": {
                    "aws": {
                        "auth": {
                            "secretRef": {
                                "accessKeyIDSecretRef": {"key": "username", "name": ACCESS_KEY_SECRET},
                                "secretAccessKeySecretRef": {"key": "password", "name": ACCESS_KEY_SECRET},
                            }
                        },
                        "region": "us-east-1",
                        "service": "SecretsManager",
                    }
                },
            },
        },
    )


SHARED_SECRET_STORE_DEFAULT = shared_secret_store("default")
SHARED_SECRET_STORE_NAMESPACE_OVERRIDE = shared_secret_store("my-namespace")


def shared_external_secret(key: str, namespace: str = "default", template: dict | None = None) -> dict:
    target = {"creationPolicy": "Owner", "deletionPolicy": "Retain", "name": "example-ctp"}
    if template is not None:
        target["template"] = template
    return kubernetes_object(
        "example-ctp-ses",
        {
            "apiVersion": "spaces.upbound.io/v1alpha1",
            "kind": "SharedExternalSecret",
            "metadata": {"name": "example-ctp", "namespace": "example-env"},
            "spec": {
                "controlPlaneSelector": {"names": ["example-ctp"]},
                "externalSecretSpec": {
                    "dataFrom": [
                        {
                            "extract": {
                                "conversionStrategy": "Default",
                                "decodingStrategy": "None",
                                "key": key,
                                "metadataPolicy": "None",
                            }
                        }
                    ],
                    "refreshInterval": "1m",
                    "secretStoreRef": {"kind": "ClusterSecretStore", "name": "example-ctp"},
                    "target": target,
                },
                "namespaceSelector": {"names": [namespace]},
            },
        },
    )


SHARED_EXTERNAL_SECRET_DEFAULT = shared_external_secret("example-env-config")
SHARED_EXTERNAL_SECRET_OVERRIDE = shared_external_secret(
    "example-config",
    namespace="my-namespace",
    template={"metadata": {"labels": {"app": "my-app", "environment": "production"}}},
)
SHARED_EXTERNAL_SECRET_NO_CREATE = shared_external_secret("existing-secret")


def secrets_manager_secret(
    name: str, annotations: dict | None = None, for_provider: dict | None = None, **spec
) -> dict:
    metadata = {"name": f"{name}-secretsmanager-secret"}
    if annotations is not None:
        metadata["annotations"] = annotations
    return {
        "apiVersion": "secretsmanager.aws.m.upbound.io/v1beta1",
        "kind": "Secret",
        "metadata": metadata,
        "spec": {"forProvider": {"name": name, "region": "us-east-1", **(for_provider or {})}, **spec},
    }


def managed_secret(name: str, annotations: dict) -> dict:
    return secrets_manager_secret(
        name, annotations, managementPolicies=ORPHAN, providerConfigRef=AWS_PROVIDER_CONFIG
    )


def external_name(name: str) -> dict:
    return {"crossplane.io/external-name": f"arn:aws:secretsmanager:us-east-1:123456789012:secret:{name}-AbCdEf"}


# Static SecretsManager Secret resources for each test case
SECRETS_MANAGER_SECRET_DEFAULT = managed_secret("example-env-config", external_name("example-env-config"))
SECRETS_MANAGER_SECRET_OVERRIDE = managed_secret("example-config", external_name("example-config"))

# Long name resources with hashing
IAM_RESOURCES_LONG_NAME = iam_resources(
    "example-shared-secret-this-is-a-very-long-1046060-secrets-read", LONG_SECRET_NAME
)
SECRETS_MANAGER_SECRET_LONG_NAME = managed_secret(
    LONG_SECRET_NAME,
    {"crossplane.io/composition-resource-name": f"{LONG_SECRET_NAME}-secretsmanager-secret"},
)
SHARED_EXTERNAL_SECRET_LONG_NAME = shared_external_secret(LONG_SECRET_NAME)


def shared_aws_secret(deletion_policy: str, secrets_manager_secret: dict | None = None) -> dict:
    aws = {
        "accountId": "123456789012",
        "region": "us-east-1",
        "namePrefix": "example-env",
        "providerConfigRef": {"name": "example-env"},
    }
    if secrets_manager_secret is not None:
        aws["secretsManagerSecret"] = secrets_manager_secret
    return {
        "apiVersion": "sa.upbound.io/v1",
        "kind": "SharedAWSSecret",
        "metadata": {"name": "example-shared-secret", "namespace": "default"},
        "spec": {
            "parameters": {
                "deletionPolicy": deletion_policy,
                "aws": aws,
                "upbound": {
                    "group": "example-env",
                    "controlPlane": "example-ctp",
                    "providerConfigRef": {"name": "example-env-group"},
                },
            }
        },
    }


def composition_test(name: str, assert_resources: list[dict], **spec) -> compositiontest.CompositionTest:
    return compositiontest.CompositionTest(
        metadata=k8s.ObjectMeta(name=name),
        spec=compositiontest.Spec(
            assertResources=assert_resources,
            compositionPath="apis/sharedawssecrets/composition.yaml",
            xrdPath="apis/sharedawssecrets/definition.yaml",
            timeoutSeconds=60,
            validate=False,
            **spec,
        ),
    )


tests = [
    # Test case 1: Default behavior using namePrefix logic
    composition_test(
        "test-sharedawssecret",
        COMMON_RESOURCES
        + IAM_RESOURCES_DEFAULT
        + [SECRETS_MANAGER_SECRET_DEFAULT, SHARED_SECRET_STORE_DEFAULT, SHARED_EXTERNAL_SECRET_DEFAULT],
        xrPath="examples/sharedawssecret/example-default.yaml",
    ),
    # Test case 2: With explicit secretsManagerSecret.name override
    composition_test(
        "test-sharedawssecret-name-override",
        COMMON_RESOURCES
        + IAM_RESOURCES_OVERRIDE
        + [SECRETS_MANAGER_SECRET_OVERRIDE, SHARED_SECRET_STORE_NAMESPACE_OVERRIDE, SHARED_EXTERNAL_SECRET_OVERRIDE],
        xrPath="examples/sharedawssecret/example.yaml",
    ),
    # Test case 3: With create set to false (no secret creation, but IAM resources still created)
    composition_test(
        "test-sharedawssecret-no-create",
        COMMON_RESOURCES
        + IAM_RESOURCES_NO_CREATE
        + [
            # No secretsManagerSecret in this case since create=false
            SHARED_SECRET_STORE_DEFAULT,
            SHARED_EXTERNAL_SECRET_NO_CREATE,
        ],
        xr=shared_aws_secret("Orphan", {"name": "existing-secret", "create": False}),
    ),
    # Test case 3b: recoveryWindowInDays reaches the managed resource.
    #
    # AWS does not delete a Secrets Manager secret outright - it schedules it, and for the
    # length of the recovery window (30 days by default) the name stays taken. Recreating a
    # secret with that name fails with "already scheduled for deletion", so any environment
    # that is torn down and stood back up under the same name is blocked until the window
    # expires. Setting 0 deletes immediately with no recovery.
    composition_test(
        "test-sharedawssecret-recovery-window",
        [
            # managementPolicies ["*"] is the schema default the KCL model materialised.
            secrets_manager_secret(
                "example-env-config", for_provider={"recoveryWindowInDays": 0}, managementPolicies=["*"]
            ),
        ],
        # create: True is the schema default the KCL model materialised.
        xr=shared_aws_secret("Delete", {"recoveryWindowInDays": 0, "create": True}),
    ),
    # Test case 4: Long name that triggers hash truncation
    composition_test(
        "test-sharedawssecret-long-name",
        COMMON_RESOURCES
        + IAM_RESOURCES_LONG_NAME
        + [SECRETS_MANAGER_SECRET_LONG_NAME, SHARED_SECRET_STORE_DEFAULT, SHARED_EXTERNAL_SECRET_LONG_NAME],
        xr=shared_aws_secret("Orphan", {"name": LONG_SECRET_NAME, "create": True}),
    ),
    # Regression guard: secretsManagerSecret is an optional block, and Environment omits it
    # whenever sharedSecret is set without one. Reading .create directly off the absent block
    # aborted the whole pipeline on a live control plane while every other case here passed,
    # because they all happen to set it.
    composition_test(
        "test-sharedawssecret-no-secretsmanager-block",
        [
            # create defaults to true when the block is absent
            secrets_manager_secret(
                "example-env-config", managementPolicies=ORPHAN, providerConfigRef=AWS_PROVIDER_CONFIG
            ),
        ],
        # secretsManagerSecret deliberately omitted
        xr=shared_aws_secret("Orphan"),
    ),
]

# The test runner expects an "items" array, one entry per test.
print(yaml.dump({"items": [t.model_dump(by_alias=True, exclude_none=True) for t in tests]}))
