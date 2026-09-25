import base64
import json

import yaml
from models.io.k8s.apimachinery.pkg.apis.meta import v1 as k8s
from models.io.upbound.dev.meta.compositiontest import v1alpha1 as compositiontest

ORCHESTRATE = ["Create", "Observe", "Update", "LateInitialize"]


def b64(s: str) -> str:
    return base64.b64encode(s.encode()).decode()


def kubernetes_object(name: str, spec: dict, metadata: dict | None = None) -> dict:
    """A kubernetes.m.crossplane.io Object, with the defaults its schema materialises."""
    spec = {"managementPolicies": ["*"], "watch": False, **spec}
    spec["forProvider"] = {"deletionPropagationPolicy": "Background", **spec["forProvider"]}
    return {
        "apiVersion": "kubernetes.m.crossplane.io/v1alpha1",
        "kind": "Object",
        "metadata": {"name": name, **(metadata or {})},
        "spec": spec,
    }


def kubeconfig_object(name: str, kubeconfig: str) -> dict:
    """A kubeconfig Secret written through the bootstrap control plane."""
    return kubernetes_object(
        name,
        {
            "forProvider": {
                "manifest": {
                    "apiVersion": "v1",
                    "kind": "Secret",
                    "metadata": {"name": name, "namespace": "default"},
                    "data": {"kubeconfig": b64(kubeconfig)},
                },
            },
            "managementPolicies": ["*"],
            "providerConfigRef": {"kind": "ProviderConfig", "name": "bootstrap-ctp"},
            "watch": False,
        },
    )


def kubernetes_provider_config(name: str, secret: str) -> dict:
    return {
        "apiVersion": "kubernetes.m.crossplane.io/v1alpha1",
        "kind": "ProviderConfig",
        "metadata": {"name": name},
        "spec": {
            "credentials": {
                "secretRef": {"key": "kubeconfig", "name": secret, "namespace": "default"},
                "source": "Secret",
            },
            "identity": {
                "secretRef": {"key": "token", "name": "upbound-token", "namespace": "default"},
                "source": "Secret",
                "type": "UpboundTokens",
            },
        },
    }


def usage(name: str, by: str) -> dict:
    return {
        "apiVersion": "protection.crossplane.io/v1beta1",
        "kind": "Usage",
        "metadata": {"name": name},
        "spec": {
            "replayDeletion": True,
            "of": {
                "apiVersion": "kubernetes.m.crossplane.io/v1alpha1",
                "kind": "Object",
                "resourceRef": {"name": name},
            },
            "by": {
                "apiVersion": "kubernetes.m.crossplane.io/v1alpha1",
                "kind": "ProviderConfig",
                "resourceRef": {"name": by},
            },
        },
    }


AWS_PROVIDER_CONFIG_REF = {"kind": "ProviderConfig", "name": "solutions-non-prod-default-example"}

# The upbound-token Secret, observed through the bootstrap control plane.
OBSERVED_ACCESS_TOKEN_SPEC = {
    "forProvider": {
        "manifest": {
            "apiVersion": "v1",
            "kind": "Secret",
            "metadata": {"name": "upbound-token", "namespace": "default"},
        },
    },
    "managementPolicies": ["Observe"],
    "providerConfigRef": {"kind": "ProviderConfig", "name": "bootstrap-ctp"},
}

test_environment = compositiontest.CompositionTest(
    metadata=k8s.ObjectMeta(name="test-environment"),
    spec=compositiontest.Spec(
        assertResources=[
            kubeconfig_object(
                "example-ctp-kubeconfig",
                "{'apiVersion': 'v1', 'clusters': [{'cluster': {'insecure-skip-tls-verify': True, 'server': 'https://upbound-aws-us-east-1.space.mxe.upbound.io/apis/spaces.upbound.io/v1beta1/namespaces/solutions-non-prod-default-example/controlplanes/example/k8s'}, 'name': 'upbound'}], 'contexts': [{'context': {'cluster': 'upbound', 'extensions': [{'extension': {'apiVersion': 'upbound.io/v1alpha1', 'kind': 'SpaceExtension', 'spec': {'cloud': {'organization': 'upbound'}}}, 'name': 'spaces.upbound.io/space'}], 'namespace': 'default', 'user': 'upbound'}, 'name': 'upbound'}], 'current-context': 'upbound', 'kind': 'Config', 'preferences': {}, 'users': [{'name': 'upbound', 'user': {'exec': {'apiVersion': 'client.authentication.k8s.io/v1', 'args': [organization, token], 'command': 'up', 'env': [{'name': 'ORGANIZATION', 'value': 'upbound'}, {'name': 'UP_PROFILE', 'value': 'default'}], 'interactiveMode': 'IfAvailable', 'provideClusterInfo': False}}}]}",
            ),
            kubernetes_object(
                "example-ctp",
                {
                    "readiness": {"policy": "DeriveFromObject"},
                    "managementPolicies": ORCHESTRATE,
                    "forProvider": {
                        "manifest": {
                            "apiVersion": "spaces.upbound.io/v1beta1",
                            "kind": "ControlPlane",
                            "metadata": {"name": "example", "namespace": "solutions-non-prod-default-example"},
                            "spec": {"class": "default", "crossplane": {"autoUpgrade": {"channel": "Rapid"}}},
                        },
                    },
                    "watch": False,
                },
            ),
            kubeconfig_object(
                "solutions-non-prod-default-example-group-kubeconfig",
                "{'apiVersion': 'v1', 'clusters': [{'cluster': {'insecure-skip-tls-verify': True, 'server': 'https://upbound-aws-us-east-1.space.mxe.upbound.io'}, 'name': 'upbound'}], 'contexts': [{'context': {'cluster': 'upbound', 'extensions': [{'extension': {'apiVersion': 'upbound.io/v1alpha1', 'kind': 'SpaceExtension', 'spec': {'cloud': {'organization': 'upbound'}}}, 'name': 'spaces.upbound.io/space'}], 'namespace': 'solutions-non-prod-default-example', 'user': 'upbound'}, 'name': 'upbound'}], 'current-context': 'upbound', 'kind': 'Config', 'preferences': {}, 'users': [{'name': 'upbound', 'user': {'exec': {'apiVersion': 'client.authentication.k8s.io/v1', 'args': [organization, token], 'command': 'up', 'env': [{'name': 'ORGANIZATION', 'value': 'upbound'}, {'name': 'UP_PROFILE', 'value': 'default'}], 'interactiveMode': 'IfAvailable', 'provideClusterInfo': False}}}]}",
            ),
            kubernetes_provider_config("example-ctp", "example-ctp-kubeconfig"),
            ### AWS ###
            {
                "apiVersion": "iam.aws.m.upbound.io/v1beta1",
                "kind": "Role",
                "metadata": {"name": "upbound-solutions-non-prod-default-example-example-admin"},
                "spec": {
                    "managementPolicies": ORCHESTRATE,
                    "forProvider": {
                        "assumeRolePolicy": r"""{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::12345678912:oidc-provider/proidc.upbound.io"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "proidc.upbound.io:sub": "mcp:upbound/example:provider:provider-aws",
                    "proidc.upbound.io:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}""",
                    },
                    "providerConfigRef": AWS_PROVIDER_CONFIG_REF,
                },
            },
            {
                "apiVersion": "iam.aws.m.upbound.io/v1beta1",
                "kind": "RolePolicyAttachment",
                "metadata": {"name": "upbound-solutions-non-prod-default-example-example-admin"},
                "spec": {
                    "forProvider": {
                        "policyArn": "arn:aws:iam::aws:policy/AdministratorAccess",
                        "roleSelector": {"matchControllerRef": True},
                    },
                    "managementPolicies": ORCHESTRATE,
                    "providerConfigRef": AWS_PROVIDER_CONFIG_REF,
                },
            },
            {
                "apiVersion": "sa.upbound.io/v1",
                "kind": "SharedAWSSecret",
                "metadata": {"name": "example-shared-secret"},
                "spec": {
                    "parameters": {
                        "deletionPolicy": "Orphan",
                        "aws": {
                            "accountId": "12345678912",
                            "region": "us-east-1",
                            "namePrefix": "upbound-solutions-non-prod-default-example-example",
                            "providerConfigRef": {"name": "solutions-non-prod-default-example"},
                        },
                        "upbound": {
                            "group": "solutions-non-prod-default-example",
                            "controlPlane": "example",
                            "providerConfigRef": {"name": "solutions-non-prod-default-example-group"},
                        },
                    },
                },
            },
            {
                "apiVersion": "aws.m.upbound.io/v1beta1",
                "kind": "ProviderConfig",
                "metadata": {
                    "annotations": {"crossplane.io/composition-resource-name": "solutions-non-prod-default-example"},
                    "labels": {"crossplane.io/composite": "example"},
                    "name": "solutions-non-prod-default-example",
                },
                "spec": {
                    "credentials": {
                        "secretRef": {"key": "credentials", "name": "aws-creds-example", "namespace": "default"},
                        "source": "Secret",
                    },
                },
            },
            kubernetes_provider_config(
                "solutions-non-prod-default-example-group", "solutions-non-prod-default-example-group-kubeconfig"
            ),
            {
                "apiVersion": "iam.aws.m.upbound.io/v1beta1",
                "kind": "OpenIDConnectProvider",
                "metadata": {"name": "upbound-solutions-non-prod-default-example-example-oidc-provider"},
                "spec": {
                    "forProvider": {"clientIdList": ["sts.amazonaws.com"], "url": "https://proidc.upbound.io"},
                    "managementPolicies": ORCHESTRATE,
                    "providerConfigRef": AWS_PROVIDER_CONFIG_REF,
                },
            },
            usage("example-space-kubeconfig", by="example-space"),
            usage("solutions-non-prod-default-example-group-kubeconfig", by="solutions-non-prod-default-example-group"),
            usage("example-ctp-kubeconfig", by="example-ctp"),
            kubeconfig_object(
                "example-space-kubeconfig",
                "{'apiVersion': 'v1', 'clusters': [{'cluster': {'insecure-skip-tls-verify': True, 'server': 'https://upbound-aws-us-east-1.space.mxe.upbound.io'}, 'name': 'upbound'}], 'contexts': [{'context': {'cluster': 'upbound', 'extensions': [{'extension': {'apiVersion': 'upbound.io/v1alpha1', 'kind': 'SpaceExtension', 'spec': {'cloud': {'organization': 'upbound'}}}, 'name': 'spaces.upbound.io/space'}], 'namespace': 'default', 'user': 'upbound'}, 'name': 'upbound'}], 'current-context': 'upbound', 'kind': 'Config', 'preferences': {}, 'users': [{'name': 'upbound', 'user': {'exec': {'apiVersion': 'client.authentication.k8s.io/v1', 'args': [organization, token], 'command': 'up', 'env': [{'name': 'ORGANIZATION', 'value': 'upbound'}, {'name': 'UP_PROFILE', 'value': 'default'}], 'interactiveMode': 'IfAvailable', 'provideClusterInfo': False}}}]}",
            ),
            kubernetes_object("example-observed-access-token-observed", OBSERVED_ACCESS_TOKEN_SPEC),
            kubernetes_object(
                "example-ctp-argocd-secret",
                {
                    "forProvider": {
                        "manifest": {
                            "apiVersion": "v1",
                            "kind": "Secret",
                            "metadata": {
                                "name": "solutions-non-prod-default-example-example",
                                "namespace": "argocd",
                                "labels": {"argocd.argoproj.io/secret-type": "cluster"},
                            },
                            "type": "Opaque",
                            "data": {
                                "name": b64("solutions-non-prod-default-example-example"),
                                "server": b64(
                                    "https://upbound-aws-us-east-1.space.mxe.upbound.io/apis/spaces.upbound.io/v1beta1/namespaces/solutions-non-prod-default-example/controlplanes/example/k8s"
                                ),
                                "config": b64(
                                    json.dumps(
                                        {
                                            "execProviderConfig": {
                                                "apiVersion": "client.authentication.k8s.io/v1",
                                                "command": "up",
                                                "args": ["org", "token"],
                                                "env": {"ORGANIZATION": "upbound", "UP_TOKEN": "uptest-token"},
                                            },
                                            "tlsClientConfig": {
                                                "insecure": False,
                                                "caData": "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJ6ekNDQVhTZ0F3SUJBZ0lSQUtuaU1IS1lkN01oQUJDbzMxRHI3cDh3Q2dZSUtvWkl6ajBFQXdJd056RUwKTUFrR0ExVUVCaE1DVlZNeEVEQU9CZ05WQkFvVEIzVndZbTkxYm1ReEZqQVVCZ05WQkFNVERWVndZbTkxYm1RcwpJRWx1WXk0d0hoY05NalV3TXpBeU1EQXpPVE0wV2hjTk1qWXdNekF5TURBek9UTTBXakEzTVFzd0NRWURWUVFHCkV3SlZVekVRTUE0R0ExVUVDaE1IZFhCaWIzVnVaREVXTUJRR0ExVUVBeE1OVlhCaWIzVnVaQ3dnU1c1akxqQloKTUJNR0J5cUdTTTQ5QWdFR0NDcUdTTTQ5QXdFSEEwSUFCTTUyUE5BWFNuQ0pHNzdWbmU2K01VVWllSW5SdmR4YQpOaDlqeW5NS3RMM2QrdWNTMTQ0R3ZLbFpiS3l1dXZzZDhrSkJyZWg3V1A3Sk9pcDFyRmU1T2d5allUQmZNQTRHCkExVWREd0VCL3dRRUF3SUJwakFkQmdOVkhTVUVGakFVQmdnckJnRUZCUWNEQVFZSUt3WUJCUVVIQXdJd0R3WUQKVlIwVEFRSC9CQVV3QXdFQi96QWRCZ05WSFE0RUZnUVUydmJKZTBVbzJjMmlsODdXOGhISWRUdHZVeWd3Q2dZSQpLb1pJemowRUF3SURTUUF3UmdJaEFLSDlLTWFHelVjcVo3NHR1aVI5VFd6S2tnakRMNWlTRWZmM0ZENktaZy9PCkFpRUFwVU8yMGZtRU9Ua0hsUHN2MTh2T1VVby8rRWJnSXo3M00waG5VQysySFJFPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==",
                                            },
                                        }
                                    )
                                ),
                            },
                        },
                    },
                },
            ),
            kubernetes_provider_config("example-space", "example-space-kubeconfig"),
        ],
        compositionPath="apis/environments/composition.yaml",
        xrPath="examples/environment/example.yaml",
        xrdPath="apis/environments/definition.yaml",
        observedResources=[
            {
                **kubernetes_object(
                    "example-observed-access-token-observed",
                    OBSERVED_ACCESS_TOKEN_SPEC,
                    metadata={
                        "namespace": "default",
                        "annotations": {"crossplane.io/composition-resource-name": "observed-access-token"},
                    },
                ),
                "status": {"atProvider": {"manifest": {"data": {"token": b64("uptest-token")}}}},
            },
            {
                **kubernetes_object(
                    "observed-bootstrap-ctp-kubeconfig",
                    {"forProvider": {"manifest": {}}, "managementPolicies": ["Observe"]},
                    metadata={
                        "annotations": {"crossplane.io/composition-resource-name": "observedCtpKubeconfig"},
                        "namespace": "default",
                    },
                ),
                "status": {
                    "atProvider": {
                        "manifest": {
                            "data": {
                                "kubeconfig": "YXBpVmVyc2lvbjogdjEKY2x1c3RlcnM6Ci0gY2x1c3RlcjoKICAgIGNlcnRpZmljYXRlLWF1dGhvcml0eS1kYXRhOiBMUzB0TFMxQ1JVZEpUaUJEUlZKVVNVWkpRMEZVUlMwdExTMHRDazFKU1VKNmVrTkRRVmhUWjBGM1NVSkJaMGxTUVV0dWFVMUlTMWxrTjAxb1FVSkRiek14UkhJM2NEaDNRMmRaU1V0dldrbDZhakJGUVhkSmQwNTZSVXdLVFVGclIwRXhWVVZDYUUxRFZsWk5lRVZFUVU5Q1owNVdRa0Z2VkVJelZuZFpiVGt4WW0xUmVFWnFRVlZDWjA1V1FrRk5WRVJXVm5kWmJUa3hZbTFSY3dwSlJXeDFXWGswZDBob1kwNU5hbFYzVFhwQmVVMUVRWHBQVkUwd1YyaGpUazFxV1hkTmVrRjVUVVJCZWs5VVRUQlhha0V6VFZGemQwTlJXVVJXVVZGSENrVjNTbFpWZWtWUlRVRTBSMEV4VlVWRGFFMUlaRmhDYVdJelZuVmFSRVZYVFVKUlIwRXhWVVZCZUUxT1ZsaENhV0l6Vm5WYVEzZG5VMWMxYWt4cVFsb0tUVUpOUjBKNWNVZFRUVFE1UVdkRlIwTkRjVWRUVFRRNVFYZEZTRUV3U1VGQ1RUVXlVRTVCV0ZOdVEwcEhOemRXYm1VMkswMVZWV2xsU1c1U2RtUjRZUXBPYURscWVXNU5TM1JNTTJRcmRXTlRNVFEwUjNaTGJGcGlTM2wxZFhaelpEaHJTa0p5WldnM1YxQTNTazlwY0RGeVJtVTFUMmQ1YWxsVVFtWk5RVFJIQ2tFeFZXUkVkMFZDTDNkUlJVRjNTVUp3YWtGa1FtZE9Wa2hUVlVWR2FrRlZRbWRuY2tKblJVWkNVV05FUVZGWlNVdDNXVUpDVVZWSVFYZEpkMFIzV1VRS1ZsSXdWRUZSU0M5Q1FWVjNRWGRGUWk5NlFXUkNaMDVXU0ZFMFJVWm5VVlV5ZG1KS1pUQlZiekpqTW1sc09EZFhPR2hJU1dSVWRIWlZlV2QzUTJkWlNRcExiMXBKZW1vd1JVRjNTVVJUVVVGM1VtZEphRUZMU0RsTFRXRkhlbFZqY1ZvM05IUjFhVkk1VkZkNlMydG5ha1JNTldsVFJXWm1NMFpFTmt0YVp5OVBDa0ZwUlVGd1ZVOHlNR1p0UlU5VWEwaHNVSE4yTVRoMlQxVlZieThyUldKblNYbzNNMDB3YUc1VlF5c3lTRkpGUFFvdExTMHRMVVZPUkNCRFJWSlVTVVpKUTBGVVJTMHRMUzB0Q2c9PQogICAgc2VydmVyOiBodHRwczovL3VwYm91bmQtYXdzLXVzLWVhc3QtMS5zcGFjZS5teGUudXBib3VuZC5pby9hcGlzL3NwYWNlcy51cGJvdW5kLmlvL3YxYmV0YTEvbmFtZXNwYWNlcy9zb2x1dGlvbnMtbm9uLXByb2QvY29udHJvbHBsYW5lcy9ib290c3RyYXAvazhzCiAgbmFtZTogdXBib3VuZApjb250ZXh0czoKLSBjb250ZXh0OgogICAgY2x1c3RlcjogdXBib3VuZAogICAgZXh0ZW5zaW9uczoKICAgIC0gZXh0ZW5zaW9uOgogICAgICAgIGFwaVZlcnNpb246IHVwYm91bmQuaW8vdjFhbHBoYTEKICAgICAgICBraW5kOiBTcGFjZUV4dGVuc2lvbgogICAgICAgIHNwZWM6CiAgICAgICAgICBjbG91ZDoKICAgICAgICAgICAgb3JnYW5pemF0aW9uOiB1cGJvdW5kCiAgICAgIG5hbWU6IHNwYWNlcy51cGJvdW5kLmlvL3NwYWNlCiAgICBuYW1lc3BhY2U6IGRlZmF1bHQKICAgIHVzZXI6IHVwYm91bmQKICBuYW1lOiB1cGJvdW5kCmN1cnJlbnQtY29udGV4dDogdXBib3VuZApraW5kOiBDb25maWcKcHJlZmVyZW5jZXM6IHt9CnVzZXJzOgotIG5hbWU6IHVwYm91bmQKICB1c2VyOgogICAgZXhlYzoKICAgICAgYXBpVmVyc2lvbjogY2xpZW50LmF1dGhlbnRpY2F0aW9uLms4cy5pby92MQogICAgICBhcmdzOgogICAgICAtIG9yZ2FuaXphdGlvbgogICAgICAtIHRva2VuCiAgICAgIGNvbW1hbmQ6IHVwCiAgICAgIGVudjoKICAgICAgLSBuYW1lOiBPUkdBTklaQVRJT04KICAgICAgICB2YWx1ZTogdXBib3VuZAogICAgICAtIG5hbWU6IFVQX1BST0ZJTEUKICAgICAgICB2YWx1ZTogZGVmYXVsdAogICAgICBpbnRlcmFjdGl2ZU1vZGU6IElmQXZhaWxhYmxlCiAgICAgIHByb3ZpZGVDbHVzdGVySW5mbzogZmFsc2UK"
                            },
                        },
                    },
                },
            },
            # Team and robot objects
            {
                "apiVersion": "m.upbound.io/v1alpha1",
                "kind": "ProviderConfig",
                "metadata": {
                    "annotations": {"crossplane.io/composition-resource-name": "providerConfigUpbound"},
                    "labels": {"crossplane.io/composite": "example"},
                    "name": "solutions-non-prod-default-example <- that this test doesn't fail is a bug, leave it here to uncover when fixed",
                    "namespace": "default",
                },
                "spec": {
                    "credentials": {
                        "secretRef": {"key": "token", "name": "upbound-token", "namespace": "default"},
                        "source": "Secret",
                    },
                    "organization": "upbound",
                },
            },
            {
                "apiVersion": "iam.m.upbound.io/v1alpha1",
                "kind": "Team",
                "metadata": {
                    "annotations": {"crossplane.io/composition-resource-name": "envTeam"},
                    "generateName": "example-",
                    "labels": {"crossplane.io/composite": "example"},
                    "name": "solutions-non-prod-default-example-team",
                    "namespace": "default",
                },
                "spec": {
                    "forProvider": {"name": "solutions-non-prod-default-example", "organizationName": "upbound"},
                    "managementPolicies": ["*"],
                    "providerConfigRef": AWS_PROVIDER_CONFIG_REF,
                },
            },
            {
                "apiVersion": "iam.m.upbound.io/v1alpha1",
                "kind": "Token",
                "metadata": {
                    "annotations": {"crossplane.io/composition-resource-name": "envRobotToken"},
                    "generateName": "example-",
                    "labels": {"crossplane.io/composite": "example"},
                    "name": "solutions-non-prod-default-example-robot-token",
                    "namespace": "default",
                },
                "spec": {
                    "forProvider": {
                        "name": "solutions-non-prod-default-example",
                        "owner": {
                            "idRef": {"name": "solutions-non-prod-default-example-robot", "namespace": "default"},
                            "type": "robots",
                        },
                    },
                    "managementPolicies": ["*"],
                    "providerConfigRef": AWS_PROVIDER_CONFIG_REF,
                    "writeConnectionSecretToRef": {"name": "solutions-non-prod-default-example-robot-token"},
                },
            },
            {
                "apiVersion": "iam.m.upbound.io/v1alpha1",
                "kind": "Robot",
                "metadata": {
                    "annotations": {"crossplane.io/composition-resource-name": "envRobot"},
                    "generateName": "example-",
                    "labels": {"crossplane.io/composite": "example"},
                    "name": "solutions-non-prod-default-example-robot",
                    "namespace": "default",
                },
                "spec": {
                    "forProvider": {
                        "description": "Robot for solutions-non-prod-default-example",
                        "name": "solutions-non-prod-default-example-bot",
                        "owner": {"name": "upbound", "namespace": "default"},
                    },
                    "managementPolicies": ["*"],
                    "providerConfigRef": AWS_PROVIDER_CONFIG_REF,
                },
            },
            {
                "apiVersion": "iam.m.upbound.io/v1alpha1",
                "kind": "RobotTeamMembership",
                "metadata": {
                    "annotations": {"crossplane.io/composition-resource-name": "envRobotTeamMembership"},
                    "generateName": "example-",
                    "labels": {"crossplane.io/composite": "example"},
                    "name": "solutions-non-prod-default-example-robot-team-membership",
                    "namespace": "default",
                },
                "spec": {
                    "forProvider": {
                        "robotIdRef": {"name": "solutions-non-prod-default-example-robot", "namespace": "default"},
                        "teamIdRef": {"name": "solutions-non-prod-default-example-team", "namespace": "default"},
                    },
                    "managementPolicies": ["*"],
                    "providerConfigRef": AWS_PROVIDER_CONFIG_REF,
                },
            },
            kubernetes_object(
                "solutions-non-prod-default-example-rt-secret",
                {
                    "forProvider": {
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
                        },
                    ],
                    "watch": False,
                },
                metadata={
                    "annotations": {"crossplane.io/composition-resource-name": "robotTokenEnvCtpSecret"},
                    "generateName": "example-",
                    "labels": {"crossplane.io/composite": "example"},
                    "namespace": "default",
                },
            ),
        ],
        timeoutSeconds=60,
        validate=False,
    ),
)

# secretsManagerSecret settings have to survive the hop into the nested SharedAWSSecret.
# recoveryWindowInDays is the one that bites: 0 is a meaningful value and a falsy one, so a
# truthy pass-through test drops it silently and teardown goes back to scheduling the secret
# for 30 days - which blocks the next run under the same name.
test_recovery_window = compositiontest.CompositionTest(
    metadata=k8s.ObjectMeta(name="test-environment-secretsmanager-recovery-window"),
    spec=compositiontest.Spec(
        assertResources=[
            {
                "apiVersion": "sa.upbound.io/v1",
                "kind": "SharedAWSSecret",
                "metadata": {"name": "example-shared-secret"},
                # `create: True` is the SharedAWSSecret schema default.
                "spec": {"parameters": {"aws": {"secretsManagerSecret": {"create": True, "recoveryWindowInDays": 0}}}},
            },
        ],
        compositionPath="apis/environments/composition.yaml",
        xrdPath="apis/environments/definition.yaml",
        xr={
            "apiVersion": "sa.upbound.io/v1",
            "kind": "Environment",
            "metadata": {"name": "example", "namespace": "default"},
            "spec": {
                "parameters": {
                    "deletionPolicy": "Delete",
                    "aws": {
                        "accountId": "12345678912",
                        "region": "us-east-1",
                        "credsSecretRef": {"name": "aws-creds-example", "namespace": "default"},
                        "sharedSecret": {
                            # `create: True` is the Environment schema default.
                            "secretsManagerSecret": {"create": True, "recoveryWindowInDays": 0},
                        },
                    },
                    "upbound": {
                        # Environment schema defaults.
                        "createArgoSecret": True,
                        "createCtp": True,
                        "createGroup": True,
                        "initProviderConfigName": "bootstrap-ctp",
                        "initKubeconfigSecretRef": {"name": "init-kubeconfig", "namespace": "default", "key": "kubeconfig"},
                        "tokenSecretRef": {"name": "upbound-token", "namespace": "default", "key": "token"},
                    },
                },
            },
            "status": {
                "upbound": {
                    "bootstrapCtp": "bootstrap",
                    "bootstrapGroup": "solutions-non-prod",
                    "org": "upbound",
                    "spaceHost": "upbound-aws-us-east-1.space.mxe.upbound.io",
                },
            },
        },
        timeoutSeconds=60,
        validate=False,
    ),
)

tests = [test_environment, test_recovery_window]

# The test runner expects an "items" array, one entry per test.
print(yaml.dump({"items": [t.model_dump(by_alias=True, exclude_none=True) for t in tests]}))
