import {
  type RunFunctionRequest,
  type RunFunctionResponse,
  type FunctionHandler,
  type Logger,
  to,
  normal,
  fatal,
  getObservedCompositeResource,
  getDesiredCompositeResource,
  getObservedComposedResources,
  getDesiredComposedResources,
  setDesiredComposedResources,
  fromObject,
  toObject,
} from '@crossplane-org/function-sdk-typescript';

import yaml from 'js-yaml';
import { kclStr, b64decode, jsonEncode } from './kcl.js';

// ---------------------------------------------------------------------------
// XR types
// ---------------------------------------------------------------------------

interface SecretRef {
  name: string;
  namespace: string;
  key?: string;
}

interface RemoteRef {
  key: string;
  property?: string;
  version?: string;
  metadataPolicy?: string;
  conversionStrategy?: string;
  decodingStrategy?: string;
}

interface ExternalSecretDataItem {
  secretKey: string;
  remoteRef: RemoteRef;
  sourceRef?: {
    generatorRef?: { apiVersion: string; kind: string; name: string };
  };
}

interface XEnvironmentParams {
  deletionPolicy?: string;
  aws?: {
    accountId: string;
    region: string;
    roleArn?: string;
    credsSecretRef?: { name: string; namespace: string };
    providerRole?: { oidcProviderArn?: string };
    sharedSecret?: {
      secretsManagerSecret?: { arn?: string; name?: string; create?: boolean };
      externalSecret?: {
        name?: string;
        namespace?: string;
        spec?: {
          data?: ExternalSecretDataItem[];
          target?: {
            template?: {
              data?: Record<string, string>;
              metadata?: { labels?: Record<string, string> };
            };
          };
        };
      };
    };
  };
  upbound: {
    createGroup?: boolean;
    createCtp?: boolean;
    createArgoSecret?: boolean;
    secretSync?: Array<{ sourceRef: { name: string; namespace: string }; destRef: { name: string; namespace: string } }>;
    tokenSecretRef: { name: string; namespace?: string; key?: string };
    initKubeconfigSecretRef: { name: string; namespace?: string; key?: string };
    initProviderConfigName?: string;
    teamWithRobot?: { teamNameOverride?: string; teamExternalName?: string };
  };
}

interface XEnvironment {
  metadata?: { name?: string };
  spec?: { parameters?: XEnvironmentParams };
  status?: {
    upbound?: {
      bootstrapCtp?: string;
      bootstrapGroup?: string;
      org?: string;
      spaceHost?: string;
    };
  };
}

type PlainObject = Record<string, unknown>;

function add(map: Record<string, ReturnType<typeof fromObject>>, key: string, obj: PlainObject): void {
  map[key] = fromObject(JSON.parse(JSON.stringify(obj)) as Record<string, unknown>);
}

// ---------------------------------------------------------------------------
// pKubernetesHelper port
// ---------------------------------------------------------------------------

function upboundKubeconfig(spaceHost: string, org: string, group: string, ctp: string): string {
  const cluster: PlainObject = { 'insecure-skip-tls-verify': true };
  if (ctp === '') {
    cluster['server'] = `https://${spaceHost}`;
  } else {
    cluster['server'] = `https://${spaceHost}/apis/spaces.upbound.io/v1beta1/namespaces/${group}/controlplanes/${ctp}/k8s`;
  }

  const context: PlainObject = {
    cluster: 'upbound',
    extensions: [
      {
        extension: {
          apiVersion: 'upbound.io/v1alpha1',
          kind: 'SpaceExtension',
          spec: { cloud: { organization: org } },
        },
        name: 'spaces.upbound.io/space',
      },
    ],
    user: 'upbound',
  };
  if (ctp === '') {
    context['namespace'] = group;
  } else {
    context['namespace'] = 'default';
  }

  const config: PlainObject = {
    apiVersion: 'v1',
    clusters: [{ cluster, name: 'upbound' }],
    contexts: [{ context, name: 'upbound' }],
    'current-context': 'upbound',
    kind: 'Config',
    preferences: {},
    users: [
      {
        name: 'upbound',
        user: {
          exec: {
            apiVersion: 'client.authentication.k8s.io/v1',
            args: ['organization', 'token'],
            command: 'up',
            env: [
              { name: 'ORGANIZATION', value: org },
              { name: 'UP_PROFILE', value: 'default' },
            ],
            interactiveMode: 'IfAvailable',
            provideClusterInfo: false,
          },
        },
      },
    ],
  };

  return kclStr(config);
}

function configName(group: string, ctp: string, prefix: string): string {
  if (ctp) return `${ctp}-ctp`;
  if (group) return `${group}-group`;
  return `${prefix}-space`;
}

function resourceName(group: string, ctp: string): string {
  if (ctp) return 'envCtp';
  if (group) return 'envGroup';
  return 'space';
}

interface UpboundProviderConfigInput {
  spaceHost: string;
  org: string;
  group?: string;
  ctp?: string;
  prefix?: string;
  providerConfigName: string;
  upboundTokenSecretRef: { name: string; namespace: string; key: string };
}

function upboundProviderConfig(
  map: Record<string, ReturnType<typeof fromObject>>,
  config: UpboundProviderConfigInput,
): void {
  const group = config.group ?? '';
  const ctp = config.ctp ?? '';
  const prefix = config.prefix ?? '';
  const rName = resourceName(group, ctp);
  const cName = configName(group, ctp, prefix);
  const secretName = `${cName}-kubeconfig`;

  const kubeObject: PlainObject = {
    apiVersion: 'kubernetes.crossplane.io/v1alpha2',
    kind: 'Object',
    metadata: {
      annotations: { 'krm.kcl.dev/composition-resource-name': `${rName}Kubeconfig` },
      name: secretName,
    },
    spec: {
      forProvider: {
        manifest: {
          apiVersion: 'v1',
          kind: 'Secret',
          metadata: { name: secretName, namespace: 'default' },
          stringData: {
            kubeconfig: upboundKubeconfig(
              config.spaceHost,
              config.org,
              group ? group : 'default',
              ctp ? ctp : '',
            ),
          },
        },
      },
      providerConfigRef: { name: config.providerConfigName },
    },
  };
  add(map, `${rName}Kubeconfig`, kubeObject);

  const providerConfig: PlainObject = {
    apiVersion: 'kubernetes.crossplane.io/v1alpha1',
    kind: 'ProviderConfig',
    metadata: {
      annotations: { 'krm.kcl.dev/composition-resource-name': `${rName}ProviderConfig`, 'krm.kcl.dev/ready': 'True' },
      name: cName,
    },
    spec: {
      credentials: {
        source: 'Secret',
        secretRef: { name: secretName, namespace: 'default', key: 'kubeconfig' },
      },
      identity: {
        type: 'UpboundTokens',
        source: 'Secret',
        secretRef: {
          name: config.upboundTokenSecretRef.name,
          namespace: config.upboundTokenSecretRef.namespace,
          key: config.upboundTokenSecretRef.key,
        },
      },
    },
  };
  add(map, `${rName}ProviderConfig`, providerConfig);

  const usage: PlainObject = {
    apiVersion: 'apiextensions.crossplane.io/v1alpha1',
    kind: 'Usage',
    metadata: {
      annotations: { 'krm.kcl.dev/composition-resource-name': `${rName}Usage` },
      name: secretName,
    },
    spec: {
      replayDeletion: true,
      of: {
        apiVersion: 'kubernetes.crossplane.io/v1alpha2',
        kind: 'Object',
        resourceRef: { name: secretName },
      },
      by: {
        apiVersion: 'kubernetes.crossplane.io/v1alpha1',
        kind: 'ProviderConfig',
        resourceRef: { name: cName },
      },
    },
  };
  add(map, `${rName}Usage`, usage);
}

// ---------------------------------------------------------------------------
// utils.observeSecret port
// ---------------------------------------------------------------------------

function observeSecret(
  map: Record<string, ReturnType<typeof fromObject>>,
  config: { ctp: string; name: string; namespace: string; providerConfigName: string; resourceName: string },
): void {
  const obj: PlainObject = {
    apiVersion: 'kubernetes.crossplane.io/v1alpha2',
    kind: 'Object',
    metadata: {
      annotations: { 'krm.kcl.dev/composition-resource-name': config.resourceName },
      name: `${config.ctp}-${config.resourceName}-observed`,
    },
    spec: {
      forProvider: {
        manifest: {
          apiVersion: 'v1',
          kind: 'Secret',
          metadata: { name: config.name, namespace: config.namespace },
        },
      },
      providerConfigRef: { name: config.providerConfigName },
      managementPolicies: ['Observe'],
    },
  };
  add(map, config.resourceName, obj);
}

// ---------------------------------------------------------------------------
// argo.argoServerSecret port
// ---------------------------------------------------------------------------

function argoServerSecret(
  map: Record<string, ReturnType<typeof fromObject>>,
  config: {
    accessToken: string;
    org: string;
    group: string;
    ctp: string;
    providerConfigName: string;
    serverCaData: string;
    spaceHost: string;
  },
): void {
  const name = `${config.group}-${config.ctp}`;
  const argoConfig = {
    execProviderConfig: {
      apiVersion: 'client.authentication.k8s.io/v1',
      command: 'up',
      args: ['org', 'token'],
      env: {
        ORGANIZATION: config.org,
        UP_TOKEN: config.accessToken,
      },
    },
    tlsClientConfig: {
      insecure: false,
      caData: config.serverCaData,
    },
  };

  const obj: PlainObject = {
    apiVersion: 'kubernetes.crossplane.io/v1alpha2',
    kind: 'Object',
    metadata: {
      annotations: { 'krm.kcl.dev/composition-resource-name': 'ctp-argocd' },
      name: `${config.ctp}-ctp-argocd-secret`,
    },
    spec: {
      forProvider: {
        manifest: {
          apiVersion: 'v1',
          kind: 'Secret',
          metadata: {
            name,
            namespace: 'argocd',
            labels: { 'argocd.argoproj.io/secret-type': 'cluster' },
          },
          type: 'Opaque',
          stringData: {
            name,
            server: `https://${config.spaceHost}/apis/spaces.upbound.io/v1beta1/namespaces/${config.group}/controlplanes/${config.ctp}/k8s`,
            config: jsonEncode(argoConfig),
          },
        },
      },
      providerConfigRef: { name: config.providerConfigName },
    },
  };
  add(map, 'ctp-argocd', obj);
}

// ---------------------------------------------------------------------------
// aws.providerConfig port
// ---------------------------------------------------------------------------

function awsProviderConfig(
  map: Record<string, ReturnType<typeof fromObject>>,
  params: { awsRoleArn?: string | undefined; awsCredsSecretRef?: { namespace: string; name: string; key: string } | undefined; envName: string },
): void {
  const spec: PlainObject = {};
  if (params.awsRoleArn) {
    spec['credentials'] = {
      source: 'Upbound',
      upbound: { webIdentity: { roleARN: params.awsRoleArn } },
    };
  } else {
    spec['credentials'] = {
      source: 'Secret',
      secretRef: params.awsCredsSecretRef,
    };
  }

  const obj: PlainObject = {
    apiVersion: 'aws.upbound.io/v1beta1',
    kind: 'ProviderConfig',
    metadata: {
      annotations: { 'krm.kcl.dev/composition-resource-name': params.envName, 'krm.kcl.dev/ready': 'True' },
      name: params.envName,
    },
    spec,
  };
  // The golden expects the composition-resource-name to be the envName (the
  // provider config name), so the map key matches.
  add(map, params.envName, obj);
}

// ---------------------------------------------------------------------------
// aws.crossplaneRole port
// ---------------------------------------------------------------------------

function getXPRoleItems(
  map: Record<string, ReturnType<typeof fromObject>>,
  params: {
    accountId: string;
    deletionPolicy: string;
    envName: string;
    ctpName: string;
    namePrefix: string;
    oidcProviderArn?: string | undefined;
    region: string;
    upboundOrg: string;
  },
): void {
  const assumeRolePolicy =
    '{\n' +
    '    "Version": "2012-10-17",\n' +
    '    "Statement": [\n' +
    '        {\n' +
    '            "Effect": "Allow",\n' +
    '            "Principal": {\n' +
    `                "Federated": "arn:aws:iam::${params.accountId}:oidc-provider/proidc.upbound.io"\n` +
    '            },\n' +
    '            "Action": "sts:AssumeRoleWithWebIdentity",\n' +
    '            "Condition": {\n' +
    '                "StringEquals": {\n' +
    `                    "proidc.upbound.io:sub": "mcp:${params.upboundOrg}/${params.ctpName}:provider:provider-aws",\n` +
    '                    "proidc.upbound.io:aud": "sts.amazonaws.com"\n' +
    '                }\n' +
    '            }\n' +
    '        }\n' +
    '    ]\n' +
    '}';

  const role: PlainObject = {
    apiVersion: 'iam.aws.upbound.io/v1beta1',
    kind: 'Role',
    metadata: {
      annotations: { 'krm.kcl.dev/composition-resource-name': 'iamAdminRole' },
      name: `${params.namePrefix}-admin`,
    },
    spec: {
      deletionPolicy: params.deletionPolicy,
      forProvider: { assumeRolePolicy },
      providerConfigRef: { name: params.envName },
    },
  };
  add(map, 'iamAdminRole', role);

  const attach: PlainObject = {
    apiVersion: 'iam.aws.upbound.io/v1beta1',
    kind: 'RolePolicyAttachment',
    metadata: {
      annotations: { 'krm.kcl.dev/composition-resource-name': 'iamAdminRoleAttach' },
      name: `${params.namePrefix}-admin`,
    },
    spec: {
      deletionPolicy: params.deletionPolicy,
      forProvider: {
        roleSelector: { matchControllerRef: true },
        policyArn: 'arn:aws:iam::aws:policy/AdministratorAccess',
      },
      providerConfigRef: { name: params.envName },
    },
  };
  add(map, 'iamAdminRoleAttach', attach);

  const oidcAnnotations: Record<string, string> = {
    'krm.kcl.dev/composition-resource-name': 'upboundOidcProvider',
  };
  if (params.oidcProviderArn) {
    oidcAnnotations['crossplane.io/external-name'] = params.oidcProviderArn;
  }
  const oidc: PlainObject = {
    apiVersion: 'iam.aws.upbound.io/v1beta1',
    kind: 'OpenIDConnectProvider',
    metadata: {
      annotations: oidcAnnotations,
      name: `${params.namePrefix}-oidc-provider`,
    },
    spec: {
      deletionPolicy: params.deletionPolicy,
      forProvider: {
        clientIdList: ['sts.amazonaws.com'],
        url: 'https://proidc.upbound.io',
      },
      providerConfigRef: { name: params.envName },
    },
  };
  add(map, 'upboundOidcProvider', oidc);
}

// ---------------------------------------------------------------------------
// teamRobot.teamWithRobot port
// ---------------------------------------------------------------------------

function teamWithRobot(
  map: Record<string, ReturnType<typeof fromObject>>,
  input: {
    group: string;
    org: string;
    secretDestProviderConfigName: string;
    spaceProviderConfigName: string;
    ocds: Record<string, ReturnType<typeof fromObject>>;
    teamNameOverride?: string | undefined;
    teamExternalName?: string | undefined;
    tokenSecretRef: { name: string; namespace: string; key: string };
    createGroupAdminBinding?: boolean | undefined;
  },
): void {
  const upboundPC = `${input.group}-upbound`;

  const providerConfig: PlainObject = {
    apiVersion: 'upbound.io/v1alpha1',
    kind: 'ProviderConfig',
    metadata: {
      annotations: { 'krm.kcl.dev/composition-resource-name': 'providerConfigUpbound', 'krm.kcl.dev/ready': 'True' },
      name: upboundPC,
    },
    spec: {
      credentials: {
        secretRef: {
          name: input.tokenSecretRef.name,
          namespace: input.tokenSecretRef.namespace,
          key: input.tokenSecretRef.key,
        },
        source: 'Secret',
      },
      organization: input.org,
    },
  };
  add(map, 'providerConfigUpbound', providerConfig);

  const robot: PlainObject = {
    apiVersion: 'iam.upbound.io/v1alpha1',
    kind: 'Robot',
    metadata: {
      annotations: { 'krm.kcl.dev/composition-resource-name': 'envRobot' },
      name: `${input.group}-robot`,
    },
    spec: {
      forProvider: {
        description: `Robot for ${input.group}`,
        name: `${input.group}-bot`,
        owner: { name: input.org },
      },
      providerConfigRef: { name: upboundPC },
    },
  };
  add(map, 'envRobot', robot);

  const token: PlainObject = {
    apiVersion: 'iam.upbound.io/v1alpha1',
    kind: 'Token',
    metadata: {
      annotations: { 'krm.kcl.dev/composition-resource-name': 'envRobotToken' },
      name: `${input.group}-robot-token`,
    },
    spec: {
      forProvider: {
        name: input.group,
        owner: { idRef: { name: `${input.group}-robot` }, type: 'robots' },
      },
      providerConfigRef: { name: upboundPC },
      writeConnectionSecretToRef: { name: `${input.group}-robot-token`, namespace: 'default' },
    },
  };
  add(map, 'envRobotToken', token);

  const teamMetadata: PlainObject = {
    annotations: { 'krm.kcl.dev/composition-resource-name': 'envTeam' } as Record<string, string>,
    name: `${input.group}-team`,
  };
  if (input.teamExternalName) {
    (teamMetadata['annotations'] as Record<string, string>)['crossplane.io/external-name'] = input.teamExternalName;
  }
  const team: PlainObject = {
    apiVersion: 'iam.upbound.io/v1alpha1',
    kind: 'Team',
    metadata: teamMetadata,
    spec: {
      deletionPolicy: 'Orphan',
      forProvider: {
        name: input.teamNameOverride || `${input.group}-team`,
        organizationName: input.org,
      },
      providerConfigRef: { name: upboundPC },
    },
  };
  add(map, 'envTeam', team);

  const membership: PlainObject = {
    apiVersion: 'iam.upbound.io/v1alpha1',
    kind: 'RobotTeamMembership',
    metadata: {
      annotations: { 'krm.kcl.dev/composition-resource-name': 'envRobotTeamMembership' },
      name: `${input.group}-robot-team-membership`,
    },
    spec: {
      forProvider: {
        robotIdRef: { name: `${input.group}-robot` },
        teamIdRef: { name: `${input.group}-team` },
      },
      providerConfigRef: { name: upboundPC },
    },
  };
  add(map, 'envRobotTeamMembership', membership);

  if (input.createGroupAdminBinding) {
    const ocdsTeam = input.ocds['envTeam'] ? toObject(input.ocds['envTeam']) : undefined;
    const externalName = (((ocdsTeam as PlainObject | undefined)?.['metadata'] as PlainObject | undefined)
      ?.['annotations'] as PlainObject | undefined)?.['crossplane.io/external-name'];

    const binding: PlainObject = {
      apiVersion: 'kubernetes.crossplane.io/v1alpha2',
      kind: 'Object',
      metadata: {
        annotations: { 'krm.kcl.dev/composition-resource-name': 'teamAdminBinding' },
        name: `${input.group}-admin-binding`,
      },
      spec: {
        forProvider: {
          manifest: {
            apiVersion: 'authorization.spaces.upbound.io/v1alpha1',
            kind: 'ObjectRoleBinding',
            metadata: { name: `${input.group}-admin-binding`, namespace: input.group },
            spec: {
              object: { apiGroup: 'core', resource: 'namespaces', name: input.group },
              subjects: [{ kind: 'UpboundTeam', role: 'admin', name: externalName }],
            },
          },
        },
        providerConfigRef: { name: input.spaceProviderConfigName },
      },
    };
    add(map, 'teamAdminBinding', binding);
  }
}

// ---------------------------------------------------------------------------
// bootstrapSecretSync.syncedSecrets port
// ---------------------------------------------------------------------------

function syncedSecrets(
  map: Record<string, ReturnType<typeof fromObject>>,
  inputs: Array<{
    sourceRef: { name: string; namespace: string };
    destRef: { name: string; namespace: string };
    providerConfigName: string;
  }>,
): void {
  for (const secret of inputs) {
    const crn = `${secret.sourceRef.namespace}-${secret.sourceRef.name}-to-${secret.destRef.namespace}-${secret.destRef.name}-syncedSecret`;
    const obj: PlainObject = {
      apiVersion: 'kubernetes.crossplane.io/v1alpha2',
      kind: 'Object',
      metadata: { annotations: { 'krm.kcl.dev/composition-resource-name': crn } },
      spec: {
        forProvider: {
          manifest: {
            apiVersion: 'v1',
            kind: 'Secret',
            metadata: { name: secret.destRef.name, namespace: secret.destRef.namespace },
          },
        },
        providerConfigRef: { name: secret.providerConfigName },
        references: [
          {
            patchesFrom: {
              apiVersion: 'v1',
              kind: 'Secret',
              name: secret.sourceRef.name,
              namespace: secret.sourceRef.namespace,
              fieldPath: 'data',
            },
            toFieldPath: 'data',
          },
        ],
      },
    };
    add(map, crn, obj);
  }
}

// ---------------------------------------------------------------------------
// XSharedAWSSecret builder (main.k inline)
// ---------------------------------------------------------------------------

function buildSharedAWSSecret(
  oxrName: string,
  params: XEnvironmentParams,
  envGroupName: string,
  namePrefix: string,
  deletionPolicy: string,
): PlainObject {
  const aws = params.aws!;
  const sharedSecret = aws.sharedSecret;

  const awsSpec: PlainObject = {
    accountId: aws.accountId,
    region: aws.region,
    namePrefix,
  };

  const sms = sharedSecret?.secretsManagerSecret;
  if (sms) {
    const smsObj: PlainObject = {};
    if (sms.arn) smsObj['arn'] = sms.arn;
    if (sms.name) smsObj['name'] = sms.name;
    if (sms.create !== undefined) smsObj['create'] = sms.create;
    awsSpec['secretsManagerSecret'] = smsObj;
  }
  awsSpec['providerConfigRef'] = { name: envGroupName };

  const parameters: PlainObject = {
    deletionPolicy,
    aws: awsSpec,
    upbound: {
      group: envGroupName,
      controlPlane: oxrName,
      providerConfigRef: { name: `${envGroupName}-group` },
    },
  };

  if (sharedSecret) {
    const externalSecret: PlainObject = {};
    const es = sharedSecret.externalSecret;
    if (es?.name) externalSecret['name'] = es.name;
    if (es?.namespace) externalSecret['namespace'] = es.namespace;
    if (es?.spec) {
      const specObj: PlainObject = {};
      if (es.spec.data) {
        specObj['data'] = es.spec.data.map((item) => {
          const remoteRef: PlainObject = { key: item.remoteRef.key };
          if (item.remoteRef.property) remoteRef['property'] = item.remoteRef.property;
          if (item.remoteRef.version) remoteRef['version'] = item.remoteRef.version;
          if (item.remoteRef.metadataPolicy) remoteRef['metadataPolicy'] = item.remoteRef.metadataPolicy;
          if (item.remoteRef.conversionStrategy) remoteRef['conversionStrategy'] = item.remoteRef.conversionStrategy;
          if (item.remoteRef.decodingStrategy) remoteRef['decodingStrategy'] = item.remoteRef.decodingStrategy;
          const entry: PlainObject = { secretKey: item.secretKey, remoteRef };
          if (item.sourceRef) {
            const sourceRef: PlainObject = {};
            if (item.sourceRef.generatorRef) {
              sourceRef['generatorRef'] = {
                apiVersion: item.sourceRef.generatorRef.apiVersion,
                kind: item.sourceRef.generatorRef.kind,
                name: item.sourceRef.generatorRef.name,
              };
            }
            entry['sourceRef'] = sourceRef;
          }
          return entry;
        });
      }
      if (es.spec.target) {
        const target: PlainObject = {};
        if (es.spec.target.template) {
          const template: PlainObject = {};
          if (es.spec.target.template.data) template['data'] = es.spec.target.template.data;
          if (es.spec.target.template.metadata) {
            const metadata: PlainObject = {};
            if (es.spec.target.template.metadata.labels) metadata['labels'] = es.spec.target.template.metadata.labels;
            template['metadata'] = metadata;
          }
          target['template'] = template;
        }
        specObj['target'] = target;
      }
      externalSecret['spec'] = specObj;
    }
    parameters['externalSecret'] = externalSecret;
  }

  return {
    apiVersion: 'sa.upbound.io/v1',
    kind: 'XSharedAWSSecret',
    metadata: {
      annotations: { 'krm.kcl.dev/composition-resource-name': 'sharedAWSSecret' },
      name: `${oxrName}-shared-secret`,
    },
    spec: { parameters },
  };
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

export class Function implements FunctionHandler {
  async RunFunction(req: RunFunctionRequest, logger?: Logger): Promise<RunFunctionResponse> {
    let rsp = to(req);

    // The KCL `oxr` is the input XR (with its full spec + status). Under
    // `crossplane render` that XR is delivered as the observed composite. (If a
    // future pipeline step ever produced a desired composite that carried the
    // parameters, we prefer whichever actually carries spec.parameters.)
    const desiredComposite = getDesiredCompositeResource(req);
    const observedComposite = getObservedCompositeResource(req);
    const desiredXr = desiredComposite?.resource as unknown as XEnvironment | undefined;
    const observedXr = observedComposite?.resource as unknown as XEnvironment | undefined;
    const oxr: XEnvironment | undefined =
      observedXr?.spec?.parameters ? observedXr : desiredXr?.spec?.parameters ? desiredXr : observedXr ?? desiredXr;
    if (!oxr) {
      fatal(rsp, 'No composite resource found');
      return rsp;
    }
    const ocds = getObservedComposedResources(req);
    const desiredComposed = getDesiredComposedResources(req);

    const oxrName = oxr.metadata?.name ?? '';

    const params = oxr.spec?.parameters;
    if (!params) {
      fatal(rsp, 'XEnvironment has no spec.parameters');
      return rsp;
    }

    const deletionPolicy = params.deletionPolicy ?? 'Orphan';
    const tokenSecretRef = {
      name: params.upbound.tokenSecretRef.name,
      namespace: params.upbound.tokenSecretRef.namespace ?? 'default',
      key: params.upbound.tokenSecretRef.key ?? 'token',
    };
    const initProviderConfigName = params.upbound.initProviderConfigName ?? 'bootstrap-ctp';
    const initKubeconfigSecretRef = {
      name: params.upbound.initKubeconfigSecretRef.name,
      namespace: params.upbound.initKubeconfigSecretRef.namespace ?? 'default',
    };
    const createCtp = params.upbound.createCtp ?? true;
    const createGroup = params.upbound.createGroup ?? true;
    const createArgoSecret = params.upbound.createArgoSecret ?? true;

    // -------------------------------------------------------------------
    // Initial Kubeconfig Processing
    // -------------------------------------------------------------------
    // KCL parses the bootstrap kubeconfig from the observed object only to obtain
    // the server CA data used by the Argo secret. The org / bootstrap-group /
    // bootstrap-controlplane / space-host values that drive resource creation are
    // read from `oxr.status.upbound` (the example XRs set status.upbound directly).
    let initKubeconfigServerCaData: string | undefined;

    const observedKubeconfigObj = ocds['observedCtpKubeconfig']
      ? (toObject(ocds['observedCtpKubeconfig']) as PlainObject | undefined)
      : undefined;
    const initialKubeconfig = (
      ((((observedKubeconfigObj?.['status'] as PlainObject | undefined)?.['atProvider'] as PlainObject | undefined)
        ?.['manifest'] as PlainObject | undefined)?.['data'] as PlainObject | undefined)?.['kubeconfig']
    ) as string | undefined;

    if (initialKubeconfig) {
      try {
        const decoded = yaml.load(b64decode(initialKubeconfig)) as PlainObject;
        const clusters = decoded?.['clusters'] as Array<PlainObject> | undefined;
        const cluster0 = clusters?.[0]?.['cluster'] as PlainObject | undefined;
        initKubeconfigServerCaData = cluster0?.['certificate-authority-data'] as string | undefined;
      } catch {
        // ignore parse failures, mirrors KCL Undefined behaviour
      }
    }

    // -------------------------------------------------------------------
    // _initItems
    // -------------------------------------------------------------------
    const status = oxr.status?.upbound;
    const initReady =
      status !== undefined &&
      status.org !== undefined &&
      status.bootstrapCtp !== undefined &&
      status.bootstrapGroup !== undefined &&
      status.spaceHost !== undefined;

    // observedCtpKubeconfig Object (Observe)
    const observedCtpKubeconfig: PlainObject = {
      apiVersion: 'kubernetes.crossplane.io/v1alpha2',
      kind: 'Object',
      metadata: {
        annotations: { 'krm.kcl.dev/composition-resource-name': 'observedCtpKubeconfig' },
        name: `${oxrName}-bootstrap-ctp-kubeconfig-observed`,
      },
      spec: {
        forProvider: {
          manifest: {
            apiVersion: 'v1',
            kind: 'Secret',
            metadata: {
              name: initKubeconfigSecretRef.name,
              namespace: initKubeconfigSecretRef.namespace,
            },
          },
        },
        providerConfigRef: { name: initProviderConfigName },
        managementPolicies: ['Observe'],
      },
    };
    add(desiredComposed, 'observedCtpKubeconfig', observedCtpKubeconfig);

    if (initReady) {
      const s = status!;
      const envGroupName = `${s.bootstrapGroup}-${oxrName}`;
      const namePrefix = `${s.org}-${envGroupName}-${oxrName}`;

      // Main controlplane
      if (createCtp) {
        const ctp: PlainObject = {
          apiVersion: 'kubernetes.crossplane.io/v1alpha2',
          kind: 'Object',
          metadata: {
            annotations: { 'krm.kcl.dev/composition-resource-name': 'ctp' },
            name: `${oxrName}-ctp`,
          },
          spec: {
            readiness: { policy: 'DeriveFromObject' },
            deletionPolicy,
            forProvider: {
              manifest: {
                apiVersion: 'spaces.upbound.io/v1beta1',
                kind: 'ControlPlane',
                metadata: {
                  name: oxrName,
                  namespace: envGroupName,
                  annotations: { foo: kclStr(params) },
                },
                spec: {
                  class: 'default',
                  crossplane: { autoUpgrade: { channel: 'Rapid' } },
                },
              },
            },
            providerConfigRef: { name: `${envGroupName}-group` },
          },
        };
        add(desiredComposed, 'ctp', ctp);
      }

      if (createGroup) {
        const envGroup: PlainObject = {
          apiVersion: 'kubernetes.crossplane.io/v1alpha2',
          kind: 'Object',
          metadata: {
            annotations: { 'krm.kcl.dev/composition-resource-name': 'envGroup' },
            name: envGroupName,
          },
          spec: {
            deletionPolicy,
            forProvider: {
              manifest: {
                apiVersion: 'v1',
                kind: 'Namespace',
                metadata: { name: envGroupName },
              },
            },
            providerConfigRef: { name: `${oxrName}-space` },
          },
        };
        add(desiredComposed, 'envGroup', envGroup);
      }

      // Argo Server Secret
      if (createArgoSecret) {
        observeSecret(desiredComposed, {
          ctp: oxrName,
          name: tokenSecretRef.name,
          namespace: tokenSecretRef.namespace,
          providerConfigName: `${s.bootstrapCtp}-ctp`,
          resourceName: 'observed-access-token',
        });

        const observedToken = ocds['observed-access-token']
          ? (toObject(ocds['observed-access-token']) as PlainObject | undefined)
          : undefined;
        const rawToken = (
          ((((observedToken?.['status'] as PlainObject | undefined)?.['atProvider'] as PlainObject | undefined)
            ?.['manifest'] as PlainObject | undefined)?.['data'] as PlainObject | undefined)?.['token']
        ) as string | undefined;

        if (rawToken) {
          const accessToken = b64decode(rawToken);
          if (accessToken) {
            argoServerSecret(desiredComposed, {
              accessToken,
              org: s.org!,
              group: envGroupName,
              ctp: oxrName,
              providerConfigName: `${s.bootstrapCtp}-ctp`,
              serverCaData: initKubeconfigServerCaData ?? '',
              spaceHost: s.spaceHost!,
            });
          }
        }
      }

      // ctp-level provider config
      if (createCtp) {
        upboundProviderConfig(desiredComposed, {
          spaceHost: s.spaceHost!,
          org: s.org!,
          group: envGroupName,
          ctp: oxrName,
          providerConfigName: `${s.bootstrapCtp}-ctp`,
          upboundTokenSecretRef: tokenSecretRef,
        });
      }

      // group-level provider config
      if (createGroup) {
        upboundProviderConfig(desiredComposed, {
          spaceHost: s.spaceHost!,
          org: s.org!,
          group: envGroupName,
          providerConfigName: `${s.bootstrapCtp}-ctp`,
          upboundTokenSecretRef: tokenSecretRef,
        });
      }

      // space-level provider config
      if (createGroup) {
        upboundProviderConfig(desiredComposed, {
          spaceHost: s.spaceHost!,
          org: s.org!,
          prefix: oxrName,
          providerConfigName: `${s.bootstrapCtp}-ctp`,
          upboundTokenSecretRef: tokenSecretRef,
        });
      }

      // team with robot
      if (params.upbound.teamWithRobot !== undefined) {
        teamWithRobot(desiredComposed, {
          group: envGroupName,
          org: s.org!,
          secretDestProviderConfigName: `${oxrName}-ctp`,
          spaceProviderConfigName: `${oxrName}-space`,
          ocds,
          teamNameOverride: params.upbound.teamWithRobot.teamNameOverride,
          teamExternalName: params.upbound.teamWithRobot.teamExternalName,
          tokenSecretRef,
          createGroupAdminBinding: createGroup,
        });
      }

      // secret sync
      if (params.upbound.secretSync) {
        syncedSecrets(
          desiredComposed,
          params.upbound.secretSync.map((secret) => ({
            sourceRef: { name: secret.sourceRef.name, namespace: secret.sourceRef.namespace },
            destRef: { name: secret.destRef.name, namespace: secret.destRef.namespace },
            providerConfigName: `${oxrName}-ctp`,
          })),
        );
      }

      // AWS features
      if (params.aws !== undefined) {
        awsProviderConfig(desiredComposed, {
          awsRoleArn: params.aws.roleArn,
          awsCredsSecretRef: params.aws.credsSecretRef
            ? {
                namespace: params.aws.credsSecretRef.namespace,
                name: params.aws.credsSecretRef.name,
                key: 'credentials',
              }
            : undefined,
          envName: envGroupName,
        });

        if (params.aws.providerRole !== undefined) {
          getXPRoleItems(desiredComposed, {
            accountId: params.aws.accountId,
            deletionPolicy,
            envName: envGroupName,
            ctpName: oxrName,
            namePrefix,
            oidcProviderArn: params.aws.providerRole.oidcProviderArn,
            region: params.aws.region,
            upboundOrg: s.org!,
          });
        }

        if (params.aws.sharedSecret !== undefined) {
          const shared = buildSharedAWSSecret(oxrName, params, envGroupName, namePrefix, deletionPolicy);
          add(desiredComposed, 'sharedAWSSecret', shared);
        }
      }
    }

    // The kubernetes.crossplane.io Object CRD defaults spec.watch to false.
    // `crossplane render` does not emit it, but the golden assertions include it,
    // so set it explicitly on every Object we emit.
    for (const key of Object.keys(desiredComposed)) {
      const res = desiredComposed[key];
      if (!res) continue;
      const obj = toObject(res) as PlainObject | undefined;
      if (obj && obj['apiVersion'] === 'kubernetes.crossplane.io/v1alpha2' && obj['kind'] === 'Object') {
        const spec = obj['spec'] as PlainObject | undefined;
        if (spec && spec['watch'] === undefined) {
          spec['watch'] = false;
          desiredComposed[key] = fromObject(JSON.parse(JSON.stringify(obj)) as Record<string, unknown>);
        }
      }
    }

    rsp = setDesiredComposedResources(rsp, desiredComposed);
    logger?.debug({ count: Object.keys(desiredComposed).length }, 'Composed XEnvironment resources');
    normal(rsp, 'Composed XEnvironment resources');
    return rsp;
  }
}
