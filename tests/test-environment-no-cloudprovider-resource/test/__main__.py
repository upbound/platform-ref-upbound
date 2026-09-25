import base64

import yaml
from models.io.k8s.apimachinery.pkg.apis.meta import v1 as k8s
from models.io.upbound.dev.meta.compositiontest import v1alpha1 as compositiontest

K8S_API = "kubernetes.m.crossplane.io/v1alpha1"
UPBOUND_PROVIDER_CONFIG = "solutions-non-prod-default-example"
COMPOSITE_LABEL = {"crossplane.io/composite": "example"}
BOOTSTRAP_PROVIDER_CONFIG_REF = {"kind": "ProviderConfig", "name": "bootstrap-ctp"}


def _b64(s: str) -> str:
    return base64.b64encode(s.encode()).decode()


def _kubeconfig_secret(name: str, kubeconfig: str) -> dict:
    """A kubeconfig Secret written to the bootstrap control plane through a provider-kubernetes Object."""
    return {
        "apiVersion": K8S_API,
        "kind": "Object",
        "metadata": {"name": name},
        "spec": {
            "forProvider": {
                "deletionPropagationPolicy": "Background",  # typed KCL schema default
                "manifest": {
                    "apiVersion": "v1",
                    "kind": "Secret",
                    "metadata": {"name": name, "namespace": "default"},
                    "data": {"kubeconfig": _b64(kubeconfig)},
                },
            },
            "managementPolicies": ["*"],
            "providerConfigRef": BOOTSTRAP_PROVIDER_CONFIG_REF,
            "watch": False,
        },
    }


def _provider_config(name: str) -> dict:
    """A provider-kubernetes ProviderConfig reading the `<name>-kubeconfig` Secret, authenticated by Upbound token."""
    return {
        "apiVersion": K8S_API,
        "kind": "ProviderConfig",
        "metadata": {"name": name},
        "spec": {
            "credentials": {
                "secretRef": {"key": "kubeconfig", "name": f"{name}-kubeconfig", "namespace": "default"},
                "source": "Secret",
            },
            "identity": {
                "secretRef": {"key": "token", "name": "upbound-token", "namespace": "default"},
                "source": "Secret",
                "type": "UpboundTokens",
            },
        },
    }


def _usage(provider_config: str) -> dict:
    """A Usage keeping the `<provider_config>-kubeconfig` Object alive while its ProviderConfig uses it."""
    secret = f"{provider_config}-kubeconfig"
    return {
        "apiVersion": "protection.crossplane.io/v1beta1",
        "kind": "Usage",
        "metadata": {"name": secret},
        "spec": {
            "replayDeletion": True,
            "of": {"apiVersion": K8S_API, "kind": "Object", "resourceRef": {"name": secret}},
            "by": {"apiVersion": K8S_API, "kind": "ProviderConfig", "resourceRef": {"name": provider_config}},
        },
    }


def _observed(kind: str, resource_name: str, name: str, spec: dict, api_version: str = "iam.m.upbound.io/v1alpha1") -> dict:
    """An observed composed resource of the Upbound team and robot set."""
    return {
        "apiVersion": api_version,
        "kind": kind,
        "metadata": {
            "annotations": {"crossplane.io/composition-resource-name": resource_name},
            "generateName": "example-",
            "labels": COMPOSITE_LABEL,
            "name": name,
            "namespace": "default",
        },
        "spec": spec,
    }


UPBOUND_PROVIDER_CONFIG_REF = {"kind": "ProviderConfig", "name": UPBOUND_PROVIDER_CONFIG}

tests = [
    compositiontest.CompositionTest(
        metadata=k8s.ObjectMeta(name="test-environment-no-cloudprovider-resource"),
        spec=compositiontest.Spec(
            assertResources=[
                _kubeconfig_secret(
                    "example-ctp-kubeconfig",
                    "{'apiVersion': 'v1', 'clusters': [{'cluster': {'insecure-skip-tls-verify': True, 'server': 'https://upbound-aws-us-east-1.space.mxe.upbound.io/apis/spaces.upbound.io/v1beta1/namespaces/solutions-non-prod-default-example/controlplanes/example/k8s'}, 'name': 'upbound'}], 'contexts': [{'context': {'cluster': 'upbound', 'extensions': [{'extension': {'apiVersion': 'upbound.io/v1alpha1', 'kind': 'SpaceExtension', 'spec': {'cloud': {'organization': 'upbound'}}}, 'name': 'spaces.upbound.io/space'}], 'namespace': 'default', 'user': 'upbound'}, 'name': 'upbound'}], 'current-context': 'upbound', 'kind': 'Config', 'preferences': {}, 'users': [{'name': 'upbound', 'user': {'exec': {'apiVersion': 'client.authentication.k8s.io/v1', 'args': [organization, token], 'command': 'up', 'env': [{'name': 'ORGANIZATION', 'value': 'upbound'}, {'name': 'UP_PROFILE', 'value': 'default'}], 'interactiveMode': 'IfAvailable', 'provideClusterInfo': False}}}]}",
                ),
                {
                    "apiVersion": K8S_API,
                    "kind": "Object",
                    "metadata": {"name": "example-ctp"},
                    "spec": {
                        "readiness": {"policy": "DeriveFromObject"},
                        "managementPolicies": ["Create", "Observe", "Update", "LateInitialize"],
                        "forProvider": {
                            "deletionPropagationPolicy": "Background",  # typed KCL schema default
                            "manifest": {
                                "apiVersion": "spaces.upbound.io/v1beta1",
                                "kind": "ControlPlane",
                                "metadata": {"name": "example", "namespace": "solutions-non-prod-default-example"},
                                "spec": {"class": "default", "crossplane": {"autoUpgrade": {"channel": "Rapid"}}},
                            },
                        },
                        "watch": False,
                    },
                },
                _kubeconfig_secret(
                    "solutions-non-prod-default-example-group-kubeconfig",
                    "{'apiVersion': 'v1', 'clusters': [{'cluster': {'insecure-skip-tls-verify': True, 'server': 'https://upbound-aws-us-east-1.space.mxe.upbound.io'}, 'name': 'upbound'}], 'contexts': [{'context': {'cluster': 'upbound', 'extensions': [{'extension': {'apiVersion': 'upbound.io/v1alpha1', 'kind': 'SpaceExtension', 'spec': {'cloud': {'organization': 'upbound'}}}, 'name': 'spaces.upbound.io/space'}], 'namespace': 'solutions-non-prod-default-example', 'user': 'upbound'}, 'name': 'upbound'}], 'current-context': 'upbound', 'kind': 'Config', 'preferences': {}, 'users': [{'name': 'upbound', 'user': {'exec': {'apiVersion': 'client.authentication.k8s.io/v1', 'args': [organization, token], 'command': 'up', 'env': [{'name': 'ORGANIZATION', 'value': 'upbound'}, {'name': 'UP_PROFILE', 'value': 'default'}], 'interactiveMode': 'IfAvailable', 'provideClusterInfo': False}}}]}",
                ),
                _provider_config("example-ctp"),
                _provider_config("solutions-non-prod-default-example-group"),
                _usage("example-space"),
                _usage("solutions-non-prod-default-example-group"),
                _usage("example-ctp"),
                _kubeconfig_secret(
                    "example-space-kubeconfig",
                    "{'apiVersion': 'v1', 'clusters': [{'cluster': {'insecure-skip-tls-verify': True, 'server': 'https://upbound-aws-us-east-1.space.mxe.upbound.io'}, 'name': 'upbound'}], 'contexts': [{'context': {'cluster': 'upbound', 'extensions': [{'extension': {'apiVersion': 'upbound.io/v1alpha1', 'kind': 'SpaceExtension', 'spec': {'cloud': {'organization': 'upbound'}}}, 'name': 'spaces.upbound.io/space'}], 'namespace': 'default', 'user': 'upbound'}, 'name': 'upbound'}], 'current-context': 'upbound', 'kind': 'Config', 'preferences': {}, 'users': [{'name': 'upbound', 'user': {'exec': {'apiVersion': 'client.authentication.k8s.io/v1', 'args': [organization, token], 'command': 'up', 'env': [{'name': 'ORGANIZATION', 'value': 'upbound'}, {'name': 'UP_PROFILE', 'value': 'default'}], 'interactiveMode': 'IfAvailable', 'provideClusterInfo': False}}}]}",
                ),
                _provider_config("example-space"),
            ],
            compositionPath="apis/environments/composition.yaml",
            xrPath="examples/environment/example-no-cloudprovider-resources.yaml",
            xrdPath="apis/environments/definition.yaml",
            context={},
            extraResources=[],
            observedResources=[
                {
                    "apiVersion": K8S_API,
                    "kind": "Object",
                    "metadata": {
                        "annotations": {"crossplane.io/composition-resource-name": "observedCtpKubeconfig"},
                        "name": "observed-bootstrap-ctp-kubeconfig",
                        "namespace": "default",
                    },
                    "spec": {
                        # deletionPropagationPolicy and watch are typed KCL schema defaults.
                        "forProvider": {"deletionPropagationPolicy": "Background", "manifest": {}},
                        "managementPolicies": ["Observe"],
                        "watch": False,
                    },
                    "status": {
                        "atProvider": {
                            "manifest": {
                                "data": {
                                    "kubeconfig": "YXBpVmVyc2lvbjogdjEKY2x1c3RlcnM6Ci0gY2x1c3RlcjoKICAgIGluc2VjdXJlLXNraXAtdGxzLXZlcmlmeTogdHJ1ZQogICAgc2VydmVyOiBodHRwczovL3VwYm91bmQtYXdzLXVzLWVhc3QtMS5zcGFjZS5teGUudXBib3VuZC5pby9hcGlzL3NwYWNlcy51cGJvdW5kLmlvL3YxYmV0YTEvbmFtZXNwYWNlcy9zb2x1dGlvbnMtbm9uLXByb2QvY29udHJvbHBsYW5lcy9ib290c3RyYXAvazhzCiAgbmFtZTogdXBib3VuZApjb250ZXh0czoKLSBjb250ZXh0OgogICAgY2x1c3RlcjogdXBib3VuZAogICAgZXh0ZW5zaW9uczoKICAgIC0gZXh0ZW5zaW9uOgogICAgICAgIGFwaVZlcnNpb246IHVwYm91bmQuaW8vdjFhbHBoYTEKICAgICAgICBraW5kOiBTcGFjZUV4dGVuc2lvbgogICAgICAgIHNwZWM6CiAgICAgICAgICBjbG91ZDoKICAgICAgICAgICAgb3JnYW5pemF0aW9uOiB1cGJvdW5kCiAgICAgIG5hbWU6IHNwYWNlcy51cGJvdW5kLmlvL3NwYWNlCiAgICBuYW1lc3BhY2U6IGRlZmF1bHQKICAgIHVzZXI6IHVwYm91bmQKICBuYW1lOiB1cGJvdW5kCmN1cnJlbnQtY29udGV4dDogdXBib3VuZApraW5kOiBDb25maWcKcHJlZmVyZW5jZXM6IHt9CnVzZXJzOgotIG5hbWU6IHVwYm91bmQKICB1c2VyOgogICAgZXhlYzoKICAgICAgYXBpVmVyc2lvbjogY2xpZW50LmF1dGhlbnRpY2F0aW9uLms4cy5pby92MQogICAgICBhcmdzOgogICAgICAtIG9yZ2FuaXphdGlvbgogICAgICAtIHRva2VuCiAgICAgIGNvbW1hbmQ6IHVwCiAgICAgIGVudjoKICAgICAgLSBuYW1lOiBPUkdBTklaQVRJT04KICAgICAgICB2YWx1ZTogdXBib3VuZAogICAgICAtIG5hbWU6IFVQX1BST0ZJTEUKICAgICAgICB2YWx1ZTogZGVmYXVsdAogICAgICBpbnRlcmFjdGl2ZU1vZGU6IElmQXZhaWxhYmxlCiAgICAgIHByb3ZpZGVDbHVzdGVySW5mbzogZmFsc2UK"
                                }
                            }
                        }
                    },
                },
                # Team and robot objects
                _observed(
                    "ProviderConfig",
                    "providerConfigUpbound",
                    UPBOUND_PROVIDER_CONFIG,
                    {
                        "credentials": {
                            "secretRef": {"key": "token", "name": "upbound-token", "namespace": "default"},
                            "source": "Secret",
                        },
                        "organization": "upbound",
                    },
                    api_version="m.upbound.io/v1alpha1",
                ),
                _observed(
                    "Team",
                    "envTeam",
                    "solutions-non-prod-default-example-team",
                    {
                        "forProvider": {"name": "solutions-non-prod-default-example", "organizationName": "upbound"},
                        "managementPolicies": ["*"],
                        "providerConfigRef": UPBOUND_PROVIDER_CONFIG_REF,
                    },
                ),
                _observed(
                    "Token",
                    "envRobotToken",
                    "solutions-non-prod-default-example-robot-token",
                    {
                        "forProvider": {
                            "name": "solutions-non-prod-default-example",
                            "owner": {
                                "idRef": {"name": "solutions-non-prod-default-example-robot", "namespace": "default"},
                                "type": "robots",
                            },
                        },
                        "managementPolicies": ["*"],
                        "providerConfigRef": UPBOUND_PROVIDER_CONFIG_REF,
                        "writeConnectionSecretToRef": {"name": "solutions-non-prod-default-example-robot-token"},
                    },
                ),
                _observed(
                    "Robot",
                    "envRobot",
                    "solutions-non-prod-default-example-robot",
                    {
                        "forProvider": {
                            "description": "Robot for solutions-non-prod-default-example",
                            "name": "solutions-non-prod-default-example-bot",
                            "owner": {"name": "upbound", "namespace": "default"},
                        },
                        "managementPolicies": ["*"],
                        "providerConfigRef": UPBOUND_PROVIDER_CONFIG_REF,
                    },
                ),
                _observed(
                    "RobotTeamMembership",
                    "envRobotTeamMembership",
                    "solutions-non-prod-default-example-robot-team-membership",
                    {
                        "forProvider": {
                            "robotIdRef": {"name": "solutions-non-prod-default-example-robot", "namespace": "default"},
                            "teamIdRef": {"name": "solutions-non-prod-default-example-team", "namespace": "default"},
                        },
                        "managementPolicies": ["*"],
                        "providerConfigRef": UPBOUND_PROVIDER_CONFIG_REF,
                    },
                ),
                _observed(
                    "Object",
                    "robotTokenEnvCtpSecret",
                    "solutions-non-prod-default-example-rt-secret",
                    {
                        "forProvider": {
                            "deletionPropagationPolicy": "Background",  # typed KCL schema default
                            "manifest": {"apiVersion": "v1", "kind": "Secret", "metadata": {"namespace": "default"}},
                        },
                        "managementPolicies": ["*"],
                        "providerConfigRef": {"kind": "ProviderConfig", "name": "example-ctp"},
                        "references": [
                            {
                                "patchesFrom": {
                                    "apiVersion": "v1",
                                    "fieldPath": "data.token",
                                    "kind": "Secret",
                                    "name": "solutions-non-prod-default-example-robot-token",
                                },
                                "toFieldPath": "data.token",
                            }
                        ],
                        "watch": False,
                    },
                    api_version=K8S_API,
                ),
            ],
            timeoutSeconds=60,
            validate=False,
        ),
    ),
]

# The test runner expects an "items" array, one entry per test.
print(yaml.dump({"items": [t.model_dump(by_alias=True, exclude_none=True) for t in tests]}))
