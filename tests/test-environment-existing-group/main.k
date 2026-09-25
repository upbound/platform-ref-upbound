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

import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesm
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.sa.v1 as sav1

_xr = sav1.Environment{
    metadata = {
        name = "example"
        namespace = "default"
    }
    spec.parameters = {
        # Delete keeps managementPolicies at ["*"] so the assertions below read plainly; the
        # deletion-policy translation itself is covered by test-environment-deletion-policy-delete.
        deletionPolicy = "Delete"
        aws = {
            accountId = "12345678912"
            region = "us-east-1"
            credsSecretRef = {name = "aws-creds-example", namespace = "default"}
            # Present so the nested SharedAWSSecret is composed - it is the second consumer
            # of the group-level ProviderConfig.
            sharedSecret = {}
        }
        upbound = {
            createGroup = False
            initKubeconfigSecretRef = {name = "init-kubeconfig"}
            tokenSecretRef = {name = "upbound-token"}
        }
    }
    status.upbound = {
        bootstrapCtp = "bootstrap"
        bootstrapGroup = "solutions-non-prod"
        org = "upbound"
        spaceHost = "upbound-aws-us-east-1.space.mxe.upbound.io"
    }
}

_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-environment-existing-group"
        spec = {
            assertResources = [
                # The group-level ProviderConfig and its kubeconfig Secret must still be
                # composed. Without them the two resources below reference nothing.
                kubernetesm.ProviderConfig{
                    metadata.name = "solutions-non-prod-default-example-group"
                    spec.credentials = {
                        source = "Secret"
                        secretRef = {
                            name = "solutions-non-prod-default-example-group-kubeconfig"
                            namespace = "default"
                            key = "kubeconfig"
                        }
                    }
                }
                kubernetesm.Object{
                    metadata.name = "solutions-non-prod-default-example-group-kubeconfig"
                    spec = {
                        forProvider.manifest = {}
                    }
                }
                # The ControlPlane goes into the pre-existing group through that ProviderConfig.
                kubernetesm.Object{
                    metadata.name = "example-ctp"
                    spec = {
                        forProvider.manifest.metadata.namespace = "solutions-non-prod-default-example"
                        providerConfigRef = {
                            kind = "ProviderConfig"
                            name = "solutions-non-prod-default-example-group"
                        }
                    }
                }
                # So does the shared secret, via the same ProviderConfig.
                sav1.SharedAWSSecret{
                    metadata.name = "example-shared-secret"
                    spec.parameters.upbound = {
                        group = "solutions-non-prod-default-example"
                        controlPlane = "example"
                        providerConfigRef.name = "solutions-non-prod-default-example-group"
                    }
                }
            ]
            compositionPath = "apis/environments/composition.yaml"
            xrdPath = "apis/environments/definition.yaml"
            xr: _xr
            timeoutSeconds = 60
            validate = False
        }
    }
]

items = _items
