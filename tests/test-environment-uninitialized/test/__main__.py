import yaml
from models.io.k8s.apimachinery.pkg.apis.meta import v1 as k8s
from models.io.upbound.dev.meta.compositiontest import v1alpha1 as compositiontest

# The first reconcile of any Environment happens before status.upbound exists. The function
# must emit only the bootstrap-kubeconfig observer and wait, rather than aborting the
# pipeline. Nothing else covers this: every other suite supplies a populated status, either
# in its example or inline, so the uninitialised branch was never rendered.
test = compositiontest.CompositionTest(
    metadata=k8s.ObjectMeta(name="test-environment-uninitialized"),
    spec=compositiontest.Spec(
        assertResources=[
            {
                "apiVersion": "kubernetes.m.crossplane.io/v1alpha1",
                "kind": "Object",
                "metadata": {"name": "fresh-bootstrap-ctp-kubeconfig-observed"},
                "spec": {
                    "forProvider": {
                        "deletionPropagationPolicy": "Background",  # Object schema default
                        "manifest": {
                            "apiVersion": "v1",
                            "kind": "Secret",
                            "metadata": {"name": "bootstrap-kubeconfig", "namespace": "default"},
                        },
                    },
                    "managementPolicies": ["Observe"],
                    "providerConfigRef": {"kind": "ProviderConfig", "name": "bootstrap-ctp"},
                    "watch": False,  # Object schema default
                },
            },
        ],
        compositionPath="apis/environments/composition.yaml",
        xrdPath="apis/environments/definition.yaml",
        xr={
            "apiVersion": "sa.upbound.io/v1",
            "kind": "Environment",
            "metadata": {"name": "fresh", "namespace": "default"},
            # `upbound = None`, not an absent status: this is the exact shape a brand new
            # XR has on a live control plane, and it is what distinguishes a correct guard
            # from one written against Undefined.
            "status": {"upbound": None},
            "spec": {
                "parameters": {
                    # Environment schema defaults.
                    "deletionPolicy": "Orphan",
                    "upbound": {
                        "createArgoSecret": True,
                        "createCtp": True,
                        "createGroup": True,
                        "initKubeconfigSecretRef": {
                            "key": "kubeconfig",  # schema default
                            "name": "bootstrap-kubeconfig",
                            "namespace": "default",
                        },
                        "initProviderConfigName": "bootstrap-ctp",  # schema default
                        "tokenSecretRef": {
                            "key": "token",  # schema default
                            "name": "bootstrap-token",
                            "namespace": "default",
                        },
                    },
                },
            },
        },
        timeoutSeconds=60,
        validate=False,
    ),
)

# The test runner expects an "items" array, one entry per test.
print(yaml.dump({"items": [test.model_dump(by_alias=True, exclude_none=True)]}))
