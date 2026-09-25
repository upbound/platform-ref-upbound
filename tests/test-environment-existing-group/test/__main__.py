"""
`createGroup: false` - deploy an environment into a group that already exists.

Not every principal that runs an Environment is allowed to create groups. Upbound RBAC is
granted per group: a team is bound to one group with an ObjectRoleBinding, and nothing grants
"create any group" short of an organization owner. An operator running under a team-scoped
robot therefore has to be handed a group that someone else created, and `createGroup: false`
is the switch for that.

Everything the composition puts *inside* the group still needs the group-level ProviderConfig,
whether or not the composition created the group - the ControlPlane references it, and so does
the nested SharedAWSSecret. Gating that ProviderConfig on `createGroup` leaves both pointing at
a ProviderConfig that is never composed, which is what this suite pins down.
"""

import yaml
from models.io.k8s.apimachinery.pkg.apis.meta import v1 as k8s
from models.io.upbound.dev.meta.compositiontest import v1alpha1 as compositiontest

GROUP = "solutions-non-prod-default-example"
GROUP_PROVIDER_CONFIG = f"{GROUP}-group"

XR = {
    "apiVersion": "sa.upbound.io/v1",
    "kind": "Environment",
    "metadata": {"name": "example", "namespace": "default"},
    "spec": {
        "parameters": {
            # Delete keeps managementPolicies at ["*"] so the assertions below read plainly; the
            # deletion-policy translation itself is covered by test-environment-deletion-policy-delete.
            "deletionPolicy": "Delete",
            "aws": {
                "accountId": "12345678912",
                "region": "us-east-1",
                "credsSecretRef": {"name": "aws-creds-example", "namespace": "default"},
                # Present so the nested SharedAWSSecret is composed - it is the second consumer
                # of the group-level ProviderConfig.
                "sharedSecret": {},
            },
            "upbound": {
                "createGroup": False,
                # Environment schema defaults.
                "createArgoSecret": True,
                "createCtp": True,
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
}

test = compositiontest.CompositionTest(
    metadata=k8s.ObjectMeta(name="test-environment-existing-group"),
    spec=compositiontest.Spec(
        assertResources=[
            # The group-level ProviderConfig and its kubeconfig Secret must still be
            # composed. Without them the two resources below reference nothing.
            {
                "apiVersion": "kubernetes.m.crossplane.io/v1alpha1",
                "kind": "ProviderConfig",
                "metadata": {"name": GROUP_PROVIDER_CONFIG},
                "spec": {
                    "credentials": {
                        "source": "Secret",
                        "secretRef": {
                            "name": f"{GROUP}-group-kubeconfig",
                            "namespace": "default",
                            "key": "kubeconfig",
                        },
                    },
                },
            },
            {
                "apiVersion": "kubernetes.m.crossplane.io/v1alpha1",
                "kind": "Object",
                "metadata": {"name": f"{GROUP}-group-kubeconfig"},
                "spec": {
                    # Object schema defaults: deletionPropagationPolicy, managementPolicies, watch.
                    "forProvider": {"deletionPropagationPolicy": "Background", "manifest": {}},
                    "managementPolicies": ["*"],
                    "watch": False,
                },
            },
            # The ControlPlane goes into the pre-existing group through that ProviderConfig.
            {
                "apiVersion": "kubernetes.m.crossplane.io/v1alpha1",
                "kind": "Object",
                "metadata": {"name": "example-ctp"},
                "spec": {
                    "forProvider": {
                        "deletionPropagationPolicy": "Background",
                        "manifest": {"metadata": {"namespace": GROUP}},
                    },
                    "managementPolicies": ["*"],
                    "providerConfigRef": {"kind": "ProviderConfig", "name": GROUP_PROVIDER_CONFIG},
                    "watch": False,
                },
            },
            # So does the shared secret, via the same ProviderConfig.
            {
                "apiVersion": "sa.upbound.io/v1",
                "kind": "SharedAWSSecret",
                "metadata": {"name": "example-shared-secret"},
                "spec": {
                    "parameters": {
                        "upbound": {
                            "group": GROUP,
                            "controlPlane": "example",
                            "providerConfigRef": {"name": GROUP_PROVIDER_CONFIG},
                        },
                    },
                },
            },
        ],
        compositionPath="apis/environments/composition.yaml",
        xrdPath="apis/environments/definition.yaml",
        xr=XR,
        timeoutSeconds=60,
        validate=False,
    ),
)

# The test runner expects an "items" array, one entry per test.
print(yaml.dump({"items": [test.model_dump(by_alias=True, exclude_none=True)]}))
