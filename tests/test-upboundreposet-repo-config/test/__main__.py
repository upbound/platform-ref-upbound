"""UpboundRepoSet: per-repository public/publish settings override the set-wide defaults."""

import yaml
from models.io.k8s.apimachinery.pkg.apis.meta import v1 as k8s
from models.io.upbound.dev.meta.compositiontest import v1alpha1 as compositiontest

NAME = "test-upboundreposet-repo-config"
ORG = "test-org"
PROVIDER_CONFIG = f"{NAME}-{ORG}-reposet"
ORPHAN = ["Create", "Observe", "Update", "LateInitialize"]


def repository(name: str, public: bool, publish: bool) -> dict:
    return {
        "apiVersion": "repository.m.upbound.io/v1alpha1",
        "kind": "Repository",
        "metadata": {
            "annotations": {
                "crosslane.io/external-name": name,
                "crossplane.io/composition-resource-name": f"{ORG}-{name}",
            },
        },
        "spec": {
            "forProvider": {"name": name, "organizationName": ORG, "public": public, "publish": publish},
            "managementPolicies": ORPHAN,
            "providerConfigRef": {"kind": "ProviderConfig", "name": PROVIDER_CONFIG},
        },
    }


test = compositiontest.CompositionTest(
    metadata=k8s.ObjectMeta(name=NAME),
    spec=compositiontest.Spec(
        assertResources=[
            repository("test1", public=True, publish=False),
            repository("test2", public=True, publish=True),
            repository("test3", public=False, publish=True),
            repository("test4", public=False, publish=False),
        ],
        compositionPath="apis/upboundreposets/composition.yaml",
        xr={
            "apiVersion": "sa.upbound.io/v1",
            "kind": "UpboundRepoSet",
            "metadata": {"name": NAME, "namespace": "default"},
            "spec": {
                "parameters": {
                    "organization": ORG,
                    "settings": {"public": False, "publish": False},
                    "permissions": {"teams": {"test-team": {"permission": "write"}}},
                    "repositories": {
                        "test1": {"public": True, "publish": False},
                        "test2": {"public": True, "publish": True},
                        "test3": {"public": False, "publish": True},
                        "test4": {},
                    },
                    "tokenSecretRef": {"key": "creds", "name": "my-secret", "namespace": "default"},
                },
            },
        },
        xrdPath="apis/upboundreposets/definition.yaml",
        timeoutSeconds=60,
        validate=False,
    ),
)

# The test runner expects an "items" array, one entry per test.
print(yaml.dump({"items": [test.model_dump(by_alias=True, exclude_none=True)]}))
