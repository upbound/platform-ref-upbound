"""SharedAWSSecret with spec.data: individual key mappings instead of extracting the whole secret.

Renders examples/sharedawssecret/example-with-data.yaml and asserts the full set of composed
resources.
"""

import json

import yaml
from models.io.k8s.apimachinery.pkg.apis.meta import v1 as k8s
from models.io.upbound.dev.meta.compositiontest import v1alpha1 as compositiontest

ORPHAN = ["Create", "Observe", "Update", "LateInitialize"]
NAME = "example-shared-secret-with-data-example-config-secrets-read"
SECRET = "example-config"
ACCESS_KEY_SECRET = "example-env-secrets-read-access-key"
AWS_PROVIDER_CONFIG = {"kind": "ProviderConfig", "name": "example-env"}
GROUP_PROVIDER_CONFIG = {"kind": "ProviderConfig", "name": "example-env-group"}
CREDS = "{{ $creds := .githubCreds | fromJson }}"


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


def iam_resource(kind: str, for_provider: dict, **spec) -> dict:
    return {
        "apiVersion": "iam.aws.m.upbound.io/v1beta1",
        "kind": kind,
        "metadata": {"name": NAME},
        "spec": {
            "forProvider": for_provider,
            "managementPolicies": ORPHAN,
            "providerConfigRef": AWS_PROVIDER_CONFIG,
            **spec,
        },
    }


def data_mapping(key: str, decoding_strategy: str = "None") -> dict:
    return {
        "secretKey": key,
        "remoteRef": {
            "conversionStrategy": "Default",
            "decodingStrategy": decoding_strategy,
            "key": SECRET,
            "metadataPolicy": "None",
            "property": key,
        },
    }


POLICY = {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:ListSecretVersionIds",
            ],
            "Resource": [f"arn:aws:secretsmanager:us-east-1:123456789012:secret:{SECRET}-*"],
        }
    ],
}

test = compositiontest.CompositionTest(
    metadata=k8s.ObjectMeta(name="test-sharedawssecret-with-data"),
    spec=compositiontest.Spec(
        assertResources=[
            # Common resources (IAM user, policy, access key, secret copy)
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
            ),
            # IAM resources
            iam_resource("Policy", {"policy": json.dumps(POLICY)}),
            iam_resource(
                "UserPolicyAttachment",
                {"policyArnSelector": {"matchControllerRef": True}, "userSelector": {"matchControllerRef": True}},
            ),
            iam_resource(
                "AccessKey",
                {"userSelector": {"matchControllerRef": True}},
                writeConnectionSecretToRef={"name": ACCESS_KEY_SECRET},
            ),
            iam_resource("User", {}),
            # Secrets Manager Secret
            {
                "apiVersion": "secretsmanager.aws.m.upbound.io/v1beta1",
                "kind": "Secret",
                "metadata": {
                    "name": f"{SECRET}-secretsmanager-secret",
                    "annotations": {
                        "crossplane.io/external-name": f"arn:aws:secretsmanager:us-east-1:123456789012:secret:{SECRET}-AbCdEf"
                    },
                },
                "spec": {
                    "forProvider": {"name": SECRET, "region": "us-east-1"},
                    "managementPolicies": ORPHAN,
                    "providerConfigRef": AWS_PROVIDER_CONFIG,
                },
            },
            # Shared Secret Store
            kubernetes_object(
                "example-ctp-sss",
                {
                    "apiVersion": "spaces.upbound.io/v1alpha1",
                    "kind": "SharedSecretStore",
                    "metadata": {"name": "example-ctp", "namespace": "example-env"},
                    "spec": {
                        "controlPlaneSelector": {"names": ["example-ctp"]},
                        "namespaceSelector": {"names": ["my-namespace"]},
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
            ),
            # Shared External Secret with data (individual key mappings)
            # This is the key test: verifies that spec.data creates individual key mappings
            kubernetes_object(
                "example-ctp-ses",
                {
                    "apiVersion": "spaces.upbound.io/v1alpha1",
                    "kind": "SharedExternalSecret",
                    "metadata": {"name": "custom-external-secret", "namespace": "example-env"},
                    "spec": {
                        "controlPlaneSelector": {"names": ["example-ctp"]},
                        "externalSecretSpec": {
                            # This is the key assertion: data should be used instead of dataFrom
                            "data": [
                                data_mapping("githubAppPrivateKey"),
                                data_mapping("githubCreds"),
                                data_mapping("databaseUrl", decoding_strategy="Base64"),
                            ],
                            "refreshInterval": "1m",
                            "secretStoreRef": {"kind": "ClusterSecretStore", "name": "example-ctp"},
                            "target": {
                                "creationPolicy": "Owner",
                                "deletionPolicy": "Retain",
                                "name": "custom-external-secret",
                                "template": {
                                    "data": {
                                        "githubAppID": CREDS + '{{ index $creds.app_auth 0 "id" }}',
                                        "githubInstallationID": CREDS + '{{ index $creds.app_auth 0 "installation_id" }}',
                                        "githubPrivateKey": CREDS
                                        + '{{ index $creds.app_auth 0 "pem_file" | replace "\\\\n" "\\n" }}',
                                        "type": "git",
                                        "url": CREDS + "https://github.com/{{ $creds.owner }}",
                                    },
                                    "engineVersion": "v2",
                                    "mergePolicy": "Replace",
                                    "metadata": {
                                        "labels": {
                                            "app": "my-app",
                                            "argocd.argoproj.io/secret-type": "repo-creds",
                                            "environment": "production",
                                        }
                                    },
                                },
                            },
                        },
                        "namespaceSelector": {"names": ["my-namespace"]},
                    },
                },
            ),
        ],
        compositionPath="apis/sharedawssecrets/composition.yaml",
        xrPath="examples/sharedawssecret/example-with-data.yaml",
        xrdPath="apis/sharedawssecrets/definition.yaml",
        timeoutSeconds=60,
        validate=False,
    ),
)

# The test runner expects an "items" array, one entry per test.
print(yaml.dump({"items": [test.model_dump(by_alias=True, exclude_none=True)]}))
