"""
Provides functionality to sync Kubernetes secrets between the bootstrap control plane and environments.

This module enables copying secret data from the bootstrap control plane to destination
environments through Crossplane's Kubernetes provider.

Schemas:
- SecretRef: Defines a reference to a Kubernetes secret with name and namespace
- SecretSyncInput: Configuration for secret synchronization including source and destination
"""

import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
import utils

schema SecretRef:
    """
    Reference to a Kubernetes secret.

    Attributes:
        name: The name of the secret
        namespace: The namespace where the secret is located
    """
    name: str
    namespace: str

schema SecretSyncInput:
    """
    Configuration for secret synchronization.

    Attributes:
        sourceRef: Reference to the source secret in bootstrap control plane
        destRef: Reference to the destination secret in the environment
    """
    sourceRef: SecretRef
    destRef: SecretRef
    providerConfigName: str

syncedSecrets = lambda input: [SecretSyncInput] -> any {
    """
    Creates Crossplane Kubernetes provider objects to sync secrets from bootstrap to environments.

    Uses the Kubernetes provider to copy secret data from bootstrap control plane to environment,
    replicating the data field while creating a new secret with the specified name
    and namespace in the destination environment.

    Args:
        input: List of SecretSyncInput configurations defining the secrets to sync

    Returns:
        List of Crossplane Kubernetes provider Object resources
    """
    [
        # Copy secret from bootstrap-ctp into destination-ctp
        kubernetesv1alpha2.Object {
            metadata = utils._metadata("{}-{}-to-{}-{}-syncedSecret".format(
                secret.sourceRef.namespace, secret.sourceRef.name,
                secret.destRef.namespace, secret.destRef.name))
            spec = {
                forProvider = {
                    manifest = {
                        apiVersion = "v1"
                        kind = "Secret"
                        metadata = {
                            name = secret.destRef.name
                            namespace = secret.destRef.namespace
                        }
                    }
                }
                providerConfigRef = {
                    name = secret.providerConfigName
                }
                references = [
                    {
                        patchesFrom = {
                            apiVersion = "v1"
                            kind = "Secret"
                            name = secret.sourceRef.name
                            namespace = secret.sourceRef.namespace
                            fieldPath = "data"
                        }
                        toFieldPath = "data"
                    }
                ]
            }
        } for secret in input
    ]
}
