import base64

import yaml
from models.io.k8s.apimachinery.pkg.apis.meta import v1 as k8s
from models.io.upbound.dev.meta.compositiontest import v1alpha1 as compositiontest

OBSERVER = {
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
}

XR = {
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
}


def composition_test(name: str, **spec) -> compositiontest.CompositionTest:
    return compositiontest.CompositionTest(
        metadata=k8s.ObjectMeta(name=name),
        spec=compositiontest.Spec(
            assertResources=[OBSERVER],
            compositionPath="apis/environments/composition.yaml",
            xrdPath="apis/environments/definition.yaml",
            xr=XR,
            timeoutSeconds=60,
            validate=False,
            **spec,
        ),
    )


tests = [
    # The first reconcile of any Environment happens before status.upbound exists. The function
    # must emit only the bootstrap-kubeconfig observer and wait, rather than aborting the
    # pipeline. Nothing else covers this: every other suite supplies a populated status, either
    # in its example or inline, so the uninitialised branch was never rendered.
    composition_test("test-environment-uninitialized"),
    # The bootstrap kubeconfig has been observed, but it carries neither a server URL nor the
    # Spaces extension naming the organization - hand-written, truncated, or for the wrong kind
    # of cluster. The coordinates cannot be derived from it, so the Environment stays
    # uninitialised and keeps waiting, exactly as before the Secret existed. It must not turn
    # into a function error that fails every reconcile of the XR.
    composition_test(
        "test-environment-malformed-bootstrap-kubeconfig",
        observedResources=[{
            **OBSERVER,
            "metadata": {
                **OBSERVER["metadata"],
                "namespace": "default",
                "annotations": {"crossplane.io/composition-resource-name": "observedCtpKubeconfig"},
            },
            "status": {"atProvider": {"manifest": {"data": {"kubeconfig": base64.b64encode(yaml.safe_dump({
                "apiVersion": "v1",
                "kind": "Config",
                "clusters": [{"name": "bootstrap", "cluster": {}}],
                "contexts": [{"name": "bootstrap", "context": {"cluster": "bootstrap"}}],
            }).encode()).decode()}}}},
        }],
    ),
]

# The test runner expects an "items" array, one entry per test.
print(yaml.dump({"items": [t.model_dump(by_alias=True, exclude_none=True) for t in tests]}))
