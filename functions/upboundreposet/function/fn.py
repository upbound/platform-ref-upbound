"""UpboundRepoSet composition function.

Manages Upbound repositories and who may use them. For an UpboundRepoSet it composes:

- one Repository per entry in spec.parameters.repositories
- one Permission per (repository, team) pair in spec.parameters.permissions.teams
- the provider-upbound ProviderConfig both of those authenticate through, built from
  spec.parameters.tokenSecretRef
"""

import grpc
from crossplane.function import logging, resource, response
from crossplane.function.proto.v1 import run_function_pb2 as fnv1
from crossplane.function.proto.v1 import run_function_pb2_grpc as grpcv1

from models.io.k8s.apimachinery.pkg.apis.meta import v1 as k8s
from models.io.upbound.m.providerconfig import v1alpha1 as pcv1alpha1
from models.io.upbound.m.repository import v1alpha1 as repov1alpha1
from models.io.upbound.m.repository.permission import v1alpha1 as permv1alpha1
from models.io.upbound.sa.upboundreposet import v1 as reposetv1

# Orphan on delete: a repository outlives the UpboundRepoSet that created it. Namespaced
# MRs have no deletionPolicy; this is the managementPolicies equivalent.
ORPHAN = ["Create", "Observe", "Update", "LateInitialize"]


class FunctionRunner(grpcv1.FunctionRunnerService):
    """A FunctionRunner handles gRPC RunFunctionRequests."""

    def __init__(self):
        """Create a new FunctionRunner."""
        self.log = logging.get_logger()

    async def RunFunction(
        self, req: fnv1.RunFunctionRequest, _: grpc.aio.ServicerContext
    ) -> fnv1.RunFunctionResponse:
        """Run the function."""
        log = self.log.bind(tag=req.meta.tag)
        rsp = response.to(req)

        xr = reposetv1.UpboundRepoSet(
            **resource.struct_to_dict(req.observed.composite.resource)
        )
        params = xr.spec.parameters
        org = params.organization
        pc_name = f"{xr.metadata.name}-{org}-reposet"
        pc_ref = {"kind": "ProviderConfig", "name": pc_name}
        repositories = params.repositories or {}
        teams = (params.permissions.teams or {}) if params.permissions else {}

        for repo, opts in repositories.items():
            resource.update(
                rsp.desired.resources[f"{org}-{repo}"],
                repov1alpha1.Repository(
                    metadata=k8s.ObjectMeta(
                        # The misspelling is inherited from the KCL function, whose output
                        # this port reproduces exactly: correcting it changes how
                        # provider-upbound identifies existing repositories, which is a
                        # behaviour change to make deliberately, on its own.
                        annotations={"crosslane.io/external-name": repo},
                    ),
                    spec=repov1alpha1.Spec(
                        managementPolicies=ORPHAN,
                        forProvider=repov1alpha1.ForProvider(
                            name=repo,
                            organizationName=org,
                            # A per-repository setting wins over the set-wide default.
                            public=opts.public if opts.public is not None else params.settings.public,
                            publish=opts.publish if opts.publish is not None else params.settings.publish,
                        ),
                        providerConfigRef=pc_ref,
                    ),
                ),
            )

        for repo in repositories:
            for team, grant in teams.items():
                resource.update(
                    rsp.desired.resources[f"{org}-{repo}-{team}"],
                    permv1alpha1.Permission(
                        spec=permv1alpha1.Spec(
                            # The API default, set explicitly: the KCL function emitted it
                            # because KCL models materialise defaults, and the rendered
                            # output is kept identical across the port.
                            managementPolicies=["*"],
                            forProvider=permv1alpha1.ForProvider(
                                organizationName=org,
                                repository=repo,
                                teamIdRef=permv1alpha1.TeamIdRef(name=team),
                                permission=grant.permission,
                            ),
                            providerConfigRef=pc_ref,
                        ),
                    ),
                )

        resource.update(
            rsp.desired.resources["providerConfigUpbound"],
            pcv1alpha1.ProviderConfig(
                metadata=k8s.ObjectMeta(name=pc_name),
                spec=pcv1alpha1.Spec(
                    credentials=pcv1alpha1.Credentials(
                        # Set explicitly: `source` is a Literal default, and update()
                        # serializes with exclude_unset, so leaving it to the default would
                        # drop it from the desired resource altogether.
                        source="Secret",
                        secretRef=pcv1alpha1.SecretRef(
                            name=params.tokenSecretRef.name,
                            namespace=params.tokenSecretRef.namespace,
                            key=params.tokenSecretRef.key,
                        ),
                    ),
                    organization=org,
                ),
            ),
        )
        # A ProviderConfig has no Ready condition of its own for function-auto-ready to read.
        rsp.desired.resources["providerConfigUpbound"].ready = fnv1.READY_TRUE

        log.info("Composed UpboundRepoSet", repositories=len(repositories), teams=len(teams))
        return rsp
