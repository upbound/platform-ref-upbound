"""UpboundRepoSet: repositories, per-team permissions, and the ProviderConfig they share.

Renders examples/upboundreposet/example.yaml - two repositories, one public and one private,
and one team with write access - and asserts the full set of composed resources.
"""

import yaml
from models.io.k8s.apimachinery.pkg.apis.meta import v1 as k8s
from models.io.upbound.dev.meta.compositiontest import v1alpha1 as compositiontest

ORG = "upboundcare"
TEAM = "solutions-non-prod-ci-team"
PROVIDER_CONFIG = f"example-{ORG}-reposet"
COMPOSITE_LABEL = {"crossplane.io/composite": "example"}
ORPHAN = ["Create", "Observe", "Update", "LateInitialize"]


def repository(name: str, public: bool) -> dict:
    return {
        "apiVersion": "repository.m.upbound.io/v1alpha1",
        "kind": "Repository",
        "metadata": {
            "annotations": {
                "crosslane.io/external-name": name,
                "crossplane.io/composition-resource-name": f"{ORG}-{name}",
            },
            "generateName": "example-",
            "labels": COMPOSITE_LABEL,
        },
        "spec": {
            "forProvider": {"name": name, "organizationName": ORG, "public": public, "publish": public},
            # Repositories are orphaned: they outlive the UpboundRepoSet.
            "managementPolicies": ORPHAN,
            "providerConfigRef": {"kind": "ProviderConfig", "name": PROVIDER_CONFIG},
        },
    }


def permission(repo: str) -> dict:
    return {
        "apiVersion": "repository.m.upbound.io/v1alpha1",
        "kind": "Permission",
        "metadata": {
            "annotations": {"crossplane.io/composition-resource-name": f"{ORG}-{repo}-{TEAM}"},
            "generateName": "example-",
            "labels": COMPOSITE_LABEL,
        },
        "spec": {
            "forProvider": {
                "organizationName": ORG,
                "permission": "write",
                "repository": repo,
                "teamIdRef": {"name": TEAM},
            },
            "managementPolicies": ["*"],
            "providerConfigRef": {"kind": "ProviderConfig", "name": PROVIDER_CONFIG},
        },
    }


test = compositiontest.CompositionTest(
    metadata=k8s.ObjectMeta(name="test-upboundreposet"),
    spec=compositiontest.Spec(
        assertResources=[
            {
                "apiVersion": "sa.upbound.io/v1",
                "kind": "UpboundRepoSet",
                "metadata": {"name": "example", "namespace": "default"},
                "spec": {"parameters": {}},
            },
            {
                "apiVersion": "m.upbound.io/v1alpha1",
                "kind": "ProviderConfig",
                "metadata": {
                    "annotations": {"crossplane.io/composition-resource-name": "providerConfigUpbound"},
                    "labels": COMPOSITE_LABEL,
                    "name": PROVIDER_CONFIG,
                },
                "spec": {
                    "credentials": {
                        "secretRef": {"key": "token", "name": "solutions-non-prod-bootstrap-token", "namespace": "default"},
                        "source": "Secret",
                    },
                    "organization": ORG,
                },
            },
            repository("configuration-aws-network", public=True),
            permission("configuration-aws-network"),
            repository("configuration-aws-network_xnetwork", public=False),
            permission("configuration-aws-network_xnetwork"),
        ],
        compositionPath="apis/upboundreposets/composition.yaml",
        xrPath="examples/upboundreposet/example.yaml",
        xrdPath="apis/upboundreposets/definition.yaml",
        timeoutSeconds=60,
        validate=False,
    ),
)

# The test runner expects an "items" array, one entry per test.
print(yaml.dump({"items": [test.model_dump(by_alias=True, exclude_none=True)]}))
