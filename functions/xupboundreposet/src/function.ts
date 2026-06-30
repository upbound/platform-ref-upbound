import {
  type RunFunctionRequest,
  type RunFunctionResponse,
  type FunctionHandler,
  type Logger,
  to,
  normal,
  fatal,
  getObservedCompositeResource,
  getDesiredComposedResources,
  setDesiredComposedResources,
  fromObject,
} from '@crossplane-org/function-sdk-typescript';

import { Repository, Permission } from 'crossplane-models/repository.upbound.io/v1alpha1';
import { ProviderConfig } from 'crossplane-models/upbound.io/v1alpha1';

interface RepoOpts {
  public?: boolean;
  publish?: boolean;
}

interface XUpboundRepoSetParams {
  organization: string;
  repositories: Record<string, RepoOpts | null>;
  permissions?: { teams?: Record<string, { permission: string }> };
  settings?: { public?: boolean; publish?: boolean };
  tokenSecretRef: { name: string; namespace: string; key: string };
}

/**
 * Function composes Upbound repositories, team permissions, and the
 * provider-upbound ProviderConfig for an XUpboundRepoSet.
 */
export class Function implements FunctionHandler {
  async RunFunction(req: RunFunctionRequest, logger?: Logger): Promise<RunFunctionResponse> {
    let rsp = to(req);

    const observedComposite = getObservedCompositeResource(req);
    if (!observedComposite) {
      fatal(rsp, 'No composite resource found');
      return rsp;
    }

    const xr = observedComposite.resource as {
      metadata?: { name?: string };
      spec?: { parameters?: XUpboundRepoSetParams };
    };
    const params = xr.spec?.parameters;
    const xrName = xr.metadata?.name ?? 'unknown';
    if (!params) {
      fatal(rsp, 'XUpboundRepoSet has no spec.parameters');
      return rsp;
    }

    const org = params.organization;
    const providerConfigName = `${xrName}-${org}-reposet`;
    const settings = params.settings ?? {};
    const repositories = params.repositories ?? {};
    const teams = params.permissions?.teams ?? {};

    const desiredComposed = getDesiredComposedResources(req);

    // One Repository per repository entry.
    for (const [repo, optsRaw] of Object.entries(repositories)) {
      const opts: RepoOpts = optsRaw ?? {};
      const repository = new Repository({
        metadata: {
          annotations: {
            'crosslane.io/external-name': repo,
          },
        },
        spec: {
          deletionPolicy: 'Orphan',
          forProvider: {
            name: repo,
            organizationName: org,
            public: opts.public !== undefined ? opts.public : (settings.public as boolean),
            publish: opts.publish !== undefined ? opts.publish : (settings.publish as boolean),
          },
          providerConfigRef: { name: providerConfigName },
        },
      });
      desiredComposed[`${org}-${repo}`] = fromObject(JSON.parse(JSON.stringify(repository)) as Record<string, unknown>);
    }

    // One Permission per repository x team combination.
    for (const repo of Object.keys(repositories)) {
      for (const [team, teamOpts] of Object.entries(teams)) {
        const permission = new Permission({
          spec: {
            forProvider: {
              organizationName: org,
              repository: repo,
              teamIdRef: { name: team },
              permission: teamOpts.permission as 'admin' | 'read' | 'write' | 'view',
            },
            providerConfigRef: { name: providerConfigName },
          },
        });
        desiredComposed[`${org}-${repo}-${team}`] = fromObject(JSON.parse(JSON.stringify(permission)) as Record<string, unknown>);
      }
    }

    // ProviderConfig for authenticating with the Upbound API.
    const providerConfig = new ProviderConfig({
      metadata: {
        name: providerConfigName,
        annotations: {
          'krm.kcl.dev/ready': 'True',
        },
      },
      spec: {
        credentials: {
          source: 'Secret',
          secretRef: {
            name: params.tokenSecretRef.name,
            namespace: params.tokenSecretRef.namespace,
            key: params.tokenSecretRef.key,
          },
        },
        organization: org,
      },
    });
    desiredComposed['providerConfigUpbound'] = fromObject(JSON.parse(JSON.stringify(providerConfig)) as Record<string, unknown>);

    rsp = setDesiredComposedResources(rsp, desiredComposed);
    normal(rsp, 'Composed Upbound repositories, permissions, and provider config');
    return rsp;
  }
}
