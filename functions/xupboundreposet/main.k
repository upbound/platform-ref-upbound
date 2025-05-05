"""
XUpboundRepoSet Function

This Crossplane composition function manages Upbound repositories and their permissions.
It creates the following resources:
- Repository resources for each repository specified in parameters
- Permission resources connecting teams to repositories with specified permission levels
- ProviderConfig for authenticating with Upbound API

Parameters:
- organization: The Upbound organization name
- repositories: Map of repository names to empty objects
- permissions.teams: Map of team names to permission objects
- tokenSecretRef: Reference to a Kubernetes secret containing the Upbound token
"""

import models.io.upbound.sa.v1 as sav1
import models.io.upbound.repository.v1alpha1 as repositoryv1alpha1
import models.io.upbound.v1alpha1 as v1alpha1

# Extract the XUpboundRepoSet object from the parameters
oxr = sav1.XUpboundRepoSet{**option("params").oxr}

# Helper function to create metadata with composition resource name annotation
_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

# Generate list of resources to create
_items = [
    # Create Repository resources for each repository specified in the parameters
    repositoryv1alpha1.Repository{
        metadata: _metadata("{}-{}".format(oxr.spec.parameters.organization, repo)) | {
            annotations: {
                "crosslane.io/external-name": repo
            }
        }
        spec = {
            # Use Orphan deletion policy to avoid repository deletion when XUpboundRepoSet is deleted
            deletionPolicy = "Orphan"
            forProvider = {
                name =repo
                organizationName = oxr.spec.parameters.organization
                public = opts.public
                publish = opts.publish
            }
            providerConfigRef = {
                name = "{}-{}-reposet".format(oxr.metadata.name, oxr.spec.parameters.organization)
            }
        }
    } for repo, opts in oxr.spec.parameters.repositories
] + [
    # Create Permission resources connecting teams to repositories with specified permission levels
    # This creates a Permission resource for each repository and team combination
    repositoryv1alpha1.Permission{
        metadata: _metadata("{}-{}-{}".format(oxr.spec.parameters.organization, repo, team))
        spec = {
            forProvider = {
                organizationName = oxr.spec.parameters.organization
                repository = repo
                teamIdRef = {
                    # Reference to the team by name
                    name = team
                }
                # Get the permission level from the parameters (read, write, admin)
                permission = oxr.spec.parameters.permissions.teams[team].permission
            }
            providerConfigRef = {
                name = "{}-{}-reposet".format(oxr.metadata.name, oxr.spec.parameters.organization)
            }
        }
    } for repo in oxr.spec.parameters.repositories for team in oxr.spec.parameters.permissions?.teams
] + [
    v1alpha1.ProviderConfig{
        metadata: _metadata("providerConfigUpbound") | {
            annotations: {
              "krm.kcl.dev/ready" = "True"
            }
            name = "{}-{}-reposet".format(oxr.metadata.name, oxr.spec.parameters.organization)
        }
        spec = {
            credentials = {
                secretRef = {
                    name = oxr.spec.parameters.tokenSecretRef.name
                    namespace = oxr.spec.parameters.tokenSecretRef.namespace
                    key = oxr.spec.parameters.tokenSecretRef.key
                }
                source = "Secret"
            }
            organization = oxr.spec.parameters.organization
        }
    }
]

items = _items
