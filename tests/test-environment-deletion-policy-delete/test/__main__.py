import yaml
from models.io.k8s.apimachinery.pkg.apis.meta import v1 as k8s
from models.io.upbound.dev.meta.compositiontest import v1alpha1 as compositiontest

COMPOSITION_PATH = "apis/environments/composition.yaml"
XRD_PATH = "apis/environments/definition.yaml"
ORPHAN = ["Create", "Observe", "Update", "LateInitialize"]
OIDC_PROVIDER_ARN = "arn:aws:iam::12345678912:oidc-provider/proidc.upbound.io"


def _object(name: str) -> dict:
    """A provider-kubernetes Object, with the defaults the typed KCL schema filled in."""
    return {
        "apiVersion": "kubernetes.m.crossplane.io/v1alpha1",
        "kind": "Object",
        "metadata": {"name": name},
        "spec": {
            "forProvider": {"deletionPropagationPolicy": "Background", "manifest": {}},
            "managementPolicies": ["*"],
            "watch": False,
        },
    }


def _aws(kind: str, name: str, management_policies: list[str] | None = None, annotations: dict | None = None) -> dict:
    metadata = {"name": name}
    if annotations:
        metadata["annotations"] = annotations
    return {
        "apiVersion": "iam.aws.m.upbound.io/v1beta1",
        "kind": kind,
        "metadata": metadata,
        "spec": {"forProvider": {}, "managementPolicies": management_policies or ["*"]},
    }


OBSERVED_BOOTSTRAP_CTP_KUBECONFIG = {
    "apiVersion": "kubernetes.m.crossplane.io/v1alpha1",
    "kind": "Object",
    "metadata": {
        "annotations": {"crossplane.io/composition-resource-name": "observedCtpKubeconfig"},
        "name": "observed-bootstrap-ctp-kubeconfig",
        "namespace": "default",
    },
    "spec": {
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
}

tests = [
    compositiontest.CompositionTest(
        metadata=k8s.ObjectMeta(name="test-environment-deletion-policy-delete"),
        spec=compositiontest.Spec(
            assertResources=[
                {
                    "apiVersion": "sa.upbound.io/v1",
                    "kind": "Environment",
                    "metadata": {"name": "example", "namespace": "default"},
                    "spec": {"parameters": {"deletionPolicy": "Delete"}},
                },
                _object("example-ctp-kubeconfig"),
                _object("example-ctp"),
                _object("solutions-non-prod-default-example-group-kubeconfig"),
                ### AWS ###
                _aws("Role", "upbound-solutions-non-prod-default-example-example-admin"),
                _aws("RolePolicyAttachment", "upbound-solutions-non-prod-default-example-example-admin"),
                {
                    "apiVersion": "sa.upbound.io/v1",
                    "kind": "SharedAWSSecret",
                    "metadata": {"name": "example-shared-secret"},
                    "spec": {
                        "parameters": {
                            "deletionPolicy": "Delete",
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
                        }
                    },
                },
                _aws("OpenIDConnectProvider", "upbound-solutions-non-prod-default-example-example-oidc-provider"),
            ],
            compositionPath=COMPOSITION_PATH,
            xrPath="examples/environment/example-deletion-policy-delete.yaml",
            xrdPath=XRD_PATH,
            context={},
            extraResources=[],
            observedResources=[OBSERVED_BOOTSTRAP_CTP_KUBECONFIG],
            timeoutSeconds=60,
            validate=False,
        ),
    ),
    # Adoption must override deletionPolicy. With an oidcProviderArn supplied the composition
    # is adopting a provider it did not create, and AWS allows only one per URL per account -
    # proidc.upbound.io is shared by every Upbound integration there. Deleting it on teardown
    # would break all of them, so it stays orphaned even though the XR says Delete. The Role
    # beside it is created by us and must still honour Delete.
    compositiontest.CompositionTest(
        metadata=k8s.ObjectMeta(name="test-environment-adopted-oidc-is-orphaned"),
        spec=compositiontest.Spec(
            assertResources=[
                _aws(
                    "OpenIDConnectProvider",
                    "upbound-solutions-non-prod-default-example-example-oidc-provider",
                    management_policies=ORPHAN,
                    annotations={"crossplane.io/external-name": OIDC_PROVIDER_ARN},
                ),
                _aws("Role", "upbound-solutions-non-prod-default-example-example-admin"),
            ],
            compositionPath=COMPOSITION_PATH,
            xrdPath=XRD_PATH,
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
                            "providerRole": {"oidcProviderArn": OIDC_PROVIDER_ARN},
                        },
                        "upbound": {
                            # createArgoSecret, createCtp, createGroup, initProviderConfigName and
                            # the secret keys and namespaces are XRD defaults the typed KCL
                            # Environment filled in.
                            "createArgoSecret": True,
                            "createCtp": True,
                            "createGroup": True,
                            "initKubeconfigSecretRef": {"key": "kubeconfig", "name": "init-kubeconfig", "namespace": "default"},
                            "initProviderConfigName": "bootstrap-ctp",
                            "tokenSecretRef": {"key": "token", "name": "upbound-token", "namespace": "default"},
                        },
                    }
                },
                "status": {
                    "upbound": {
                        "bootstrapCtp": "bootstrap",
                        "bootstrapGroup": "solutions-non-prod",
                        "org": "upbound",
                        "spaceHost": "upbound-aws-us-east-1.space.mxe.upbound.io",
                    }
                },
            },
            timeoutSeconds=60,
            validate=False,
        ),
    ),
]

# The test runner expects an "items" array, one entry per test.
print(yaml.dump({"items": [t.model_dump(by_alias=True, exclude_none=True) for t in tests]}))
