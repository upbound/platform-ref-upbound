"""Environment names must not collide across namespaces.

With a Namespaced XRD, team-a/prod and team-b/prod are both valid, and everything the
composition creates *outside* the XR's namespace has to tell them apart: the Upbound group
(and so the ControlPlane, Team, Robot and Argo secret inside or named after it), the AWS
resource names, and the kubeconfig Secrets on the bootstrap control plane. Built from
metadata.name alone, the two map to the same objects - and with deletionPolicy: Delete,
deleting one tears down the other.
"""

import yaml
from models.io.k8s.apimachinery.pkg.apis.meta import v1 as k8s
from models.io.upbound.dev.meta.compositiontest import v1alpha1 as compositiontest

COMPOSITION_PATH = "apis/environments/composition.yaml"
XRD_PATH = "apis/environments/definition.yaml"


def _xr(namespace: str, name: str) -> dict:
    return {
        "apiVersion": "sa.upbound.io/v1",
        "kind": "Environment",
        "metadata": {"name": name, "namespace": namespace},
        "spec": {
            "parameters": {
                "deletionPolicy": "Delete",
                "aws": {
                    "accountId": "12345678912",
                    "region": "us-east-1",
                    "credsSecretRef": {"name": "aws-creds-example", "namespace": namespace},
                    "providerRole": {},
                },
                "upbound": {
                    # createArgoSecret, createCtp, createGroup, initProviderConfigName and the
                    # secret keys are XRD defaults the typed KCL Environment filled in.
                    "createArgoSecret": True,
                    "createCtp": True,
                    "createGroup": True,
                    "initKubeconfigSecretRef": {"key": "kubeconfig", "name": "init-kubeconfig", "namespace": namespace},
                    "initProviderConfigName": "bootstrap-ctp",
                    "tokenSecretRef": {"key": "token", "name": "upbound-token", "namespace": namespace},
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
    }


def _object(name: str, manifest_metadata: dict) -> dict:
    """A provider-kubernetes Object, with the defaults the typed KCL schema filled in."""
    return {
        "apiVersion": "kubernetes.m.crossplane.io/v1alpha1",
        "kind": "Object",
        "metadata": {"name": name},
        "spec": {
            "forProvider": {
                "deletionPropagationPolicy": "Background",
                "manifest": {"metadata": manifest_metadata},
            },
            "managementPolicies": ["*"],
            "watch": False,
        },
    }


def _role(name: str) -> dict:
    return {
        "apiVersion": "iam.aws.m.upbound.io/v1beta1",
        "kind": "Role",
        "metadata": {"name": name},
        "spec": {"forProvider": {}, "managementPolicies": ["*"]},
    }


tests = [
    compositiontest.CompositionTest(
        metadata=k8s.ObjectMeta(name="test-environment-namespaced-names"),
        spec=compositiontest.Spec(
            assertResources=[
                # The group carries the namespace, so team-b/example gets a different one.
                _object("solutions-non-prod-team-a-example", {"name": "solutions-non-prod-team-a-example"}),
                _object("example-ctp", {"namespace": "solutions-non-prod-team-a-example"}),
                # Kubeconfig Secrets land in the XR's own namespace rather than a shared
                # `default`, and the ProviderConfig reads them from there.
                _object(
                    "solutions-non-prod-team-a-example-group-kubeconfig",
                    {"name": "solutions-non-prod-team-a-example-group-kubeconfig", "namespace": "team-a"},
                ),
                {
                    "apiVersion": "kubernetes.m.crossplane.io/v1alpha1",
                    "kind": "ProviderConfig",
                    "metadata": {"name": "solutions-non-prod-team-a-example-group"},
                    "spec": {
                        "credentials": {
                            "source": "Secret",
                            "secretRef": {
                                "name": "solutions-non-prod-team-a-example-group-kubeconfig",
                                "namespace": "team-a",
                                "key": "kubeconfig",
                            },
                        }
                    },
                },
                _object("example-ctp-kubeconfig", {"namespace": "team-a"}),
                _object("example-space-kubeconfig", {"namespace": "team-a"}),
                # AWS names follow the group, so they are distinct too.
                _role("upbound-solutions-non-prod-team-a-example-example-admin"),
            ],
            compositionPath=COMPOSITION_PATH,
            xrdPath=XRD_PATH,
            xr=_xr("team-a", "example"),
            timeoutSeconds=60,
            validate=False,
        ),
    ),
    # Adding the namespace lengthens every AWS name. IAM caps role names at 64 characters,
    # and a real org/group/namespace/name combination passes that easily - AWS would then
    # reject the Role outright. It gets the same truncation SharedAWSSecret already applies
    # to its IAM user and policy: keep the suffix, replace the tail of the prefix with a hash.
    compositiontest.CompositionTest(
        metadata=k8s.ObjectMeta(name="test-environment-long-role-name"),
        spec=compositiontest.Spec(
            assertResources=[
                # 81 characters untruncated.
                _role("upbound-solutions-non-prod-platform-engineering-p-289801-admin"),
            ],
            compositionPath=COMPOSITION_PATH,
            xrdPath=XRD_PATH,
            xr=_xr("platform-engineering", "production-eu"),
            timeoutSeconds=60,
            validate=False,
        ),
    ),
]

# The test runner expects an "items" array, one entry per test.
print(yaml.dump({"items": [t.model_dump(by_alias=True, exclude_none=True) for t in tests]}))
