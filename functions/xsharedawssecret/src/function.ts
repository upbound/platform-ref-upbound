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

import { User, Policy, UserPolicyAttachment, AccessKey } from 'crossplane-models/iam.aws.upbound.io/v1beta1';
import { Secret } from 'crossplane-models/secretsmanager.aws.upbound.io/v1beta1';
import { Object as KubernetesObject } from 'crossplane-models/kubernetes.crossplane.io/v1alpha2';

// ---- Types mirroring the XSharedAWSSecret XRD spec.parameters ----

interface SecretsManagerSecretParam {
  arn?: string;
  name?: string;
  create?: boolean;
}

interface RemoteRef {
  key: string;
  property?: string;
  version?: string;
  metadataPolicy?: string;
  conversionStrategy?: string;
  decodingStrategy?: string;
}

interface DataEntry {
  secretKey: string;
  remoteRef: RemoteRef;
  sourceRef?: unknown;
}

interface ExternalSecretParam {
  name?: string;
  namespace?: string;
  spec?: {
    data?: DataEntry[];
    target?: {
      template?: {
        data?: Record<string, string>;
        metadata?: { labels?: Record<string, string> };
      };
    };
  };
}

interface XSharedAWSSecretParams {
  deletionPolicy?: string;
  aws: {
    accountId: string;
    region: string;
    namePrefix: string;
    secretsManagerSecret?: SecretsManagerSecretParam;
    providerConfigRef: { name: string };
  };
  upbound: {
    group: string;
    controlPlane: string;
    providerConfigRef: { name: string };
  };
  externalSecret?: ExternalSecretParam;
}

// ---- Helper functions ported from the KCL source ----

// Serialize a value to JSON matching KCL's `json.encode` default output:
// ", " between items and ": " between keys and values (Python json.dumps style).
function kclJsonEncode(value: unknown): string {
  if (value === null) return 'null';
  if (typeof value === 'string') return JSON.stringify(value);
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (Array.isArray(value)) {
    return `[${value.map((v) => kclJsonEncode(v)).join(', ')}]`;
  }
  if (typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>).map(
      ([k, v]) => `${JSON.stringify(k)}: ${kclJsonEncode(v)}`,
    );
    return `{${entries.join(', ')}}`;
  }
  return JSON.stringify(value);
}

// Simple hash function for string using character sum.
function simpleHash(s: string): string {
  const hash = s.length * 31;
  let result = 0;
  for (let i = 0; i < s.length; i++) {
    result += s.charCodeAt(i) * (i + 1);
  }
  return String(Math.abs(hash + result)).slice(0, 8);
}

// Truncate IAM resource names to 64 characters. When name exceeds the limit,
// replace prefix with hash to preserve suffix.
function truncateIamName(name: string, suffix: string): string {
  const maxLength = 64;
  const suffixLength = suffix.length;
  const hashLength = 8;
  const separatorLength = 1;
  const prefixSpace = maxLength - suffixLength - hashLength - separatorLength;
  const baseName = name.slice(0, name.length - suffixLength);
  const hash = simpleHash(baseName);

  if (name.length <= maxLength) {
    return name;
  }
  if (prefixSpace > 0) {
    return `${baseName.slice(0, prefixSpace).replace(/-+$/, '')}-${hash}${suffix}`;
  }
  return `${hash}${suffix}`;
}

/**
 * Function composes the IAM user/policy/access-key workaround plus the
 * SharedSecretStore and SharedExternalSecret for an XSharedAWSSecret.
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
      spec?: { parameters?: XSharedAWSSecretParams };
    };
    const params = xr.spec?.parameters;
    const xrName = xr.metadata?.name ?? 'unknown';
    if (!params) {
      fatal(rsp, 'XSharedAWSSecret has no spec.parameters');
      return rsp;
    }

    // Extract parameters from the XR spec.
    const deletionPolicy = params.deletionPolicy || 'Orphan';
    const accountId = params.aws.accountId;
    const region = params.aws.region;

    const sms = params.aws.secretsManagerSecret;
    const secretsManagerSecretArn = sms?.arn;
    const secretsManagerSecretName = sms?.name;
    let secretsManagerSecretCreate = true;
    if (sms?.create !== undefined) {
      secretsManagerSecretCreate = sms.create;
    }

    const groupName = params.upbound.group;
    const ctpName = params.upbound.controlPlane;
    const namePrefix = params.aws.namePrefix;
    const awsSecretName = secretsManagerSecretName || `${namePrefix}-config`;
    const awsProviderConfigName = params.aws.providerConfigRef.name;
    const upboundProviderConfigName = params.upbound.providerConfigRef.name;

    const es = params.externalSecret;
    const secretLabels = es?.spec?.target?.template?.metadata?.labels;
    const secretNamespace = es?.namespace || 'default';
    const secretData = es?.spec?.data;
    const secretTemplateData = es?.spec?.target?.template?.data;
    const externalSecretName = es?.name || ctpName;

    const iamName = truncateIamName(`${xrName}-${awsSecretName}-secrets-read`, '-secrets-read');

    const desiredComposed = getDesiredComposedResources(req);

    // ### Needed until SharedSecretStore supports IAM Roles ###

    const iamUser = new User({
      metadata: { name: iamName },
      spec: {
        deletionPolicy: deletionPolicy as 'Orphan' | 'Delete',
        forProvider: {},
        providerConfigRef: { name: awsProviderConfigName },
      },
    });
    desiredComposed['iamUserSecretRead'] = fromObject(JSON.parse(JSON.stringify(iamUser)) as Record<string, unknown>);

    const policyDoc = {
      Version: '2012-10-17',
      Statement: [
        {
          Effect: 'Allow',
          Action: [
            'secretsmanager:GetSecretValue',
            'secretsmanager:DescribeSecret',
            'secretsmanager:ListSecretVersionIds',
          ],
          Resource: [
            `arn:aws:secretsmanager:${region}:${accountId}:secret:${awsSecretName}-*`,
          ],
        },
      ],
    };
    const iamPolicy = new Policy({
      metadata: { name: iamName },
      spec: {
        deletionPolicy: deletionPolicy as 'Orphan' | 'Delete',
        forProvider: {
          policy: kclJsonEncode(policyDoc),
        },
        providerConfigRef: { name: awsProviderConfigName },
      },
    });
    desiredComposed['iamPolicySecretRead'] = fromObject(JSON.parse(JSON.stringify(iamPolicy)) as Record<string, unknown>);

    const iamAttach = new UserPolicyAttachment({
      metadata: { name: iamName },
      spec: {
        deletionPolicy: deletionPolicy as 'Orphan' | 'Delete',
        forProvider: {
          policyArnSelector: { matchControllerRef: true },
          userSelector: { matchControllerRef: true },
        },
        providerConfigRef: { name: awsProviderConfigName },
      },
    });
    desiredComposed['iamPolicySecretReadAttach'] = fromObject(JSON.parse(JSON.stringify(iamAttach)) as Record<string, unknown>);

    const iamAccessKey = new AccessKey({
      metadata: { name: iamName },
      spec: {
        deletionPolicy: deletionPolicy as 'Orphan' | 'Delete',
        forProvider: {
          userSelector: { matchControllerRef: true },
        },
        providerConfigRef: { name: awsProviderConfigName },
        writeConnectionSecretToRef: {
          name: `${groupName}-secrets-read-access-key`,
          namespace: 'default',
        },
      },
    });
    desiredComposed['iamUserAccessKey'] = fromObject(JSON.parse(JSON.stringify(iamAccessKey)) as Record<string, unknown>);

    // copy the iam access key secret
    const envIamUserKeySecret = new KubernetesObject({
      metadata: { name: `${groupName}-secrets-read-access-key` },
      spec: {
        deletionPolicy: deletionPolicy as 'Orphan' | 'Delete',
        watch: false,
        forProvider: {
          manifest: {
            apiVersion: 'v1',
            kind: 'Secret',
            metadata: {
              name: `${groupName}-secrets-read-access-key`,
              namespace: groupName,
            },
          },
        },
        providerConfigRef: { name: upboundProviderConfigName },
        references: [
          {
            patchesFrom: {
              apiVersion: 'v1',
              kind: 'Secret',
              name: `${groupName}-secrets-read-access-key`,
              namespace: 'default',
              fieldPath: 'data',
            },
            toFieldPath: 'data',
          },
        ],
      },
    });
    desiredComposed['envIamUserKeySecret'] = fromObject(JSON.parse(JSON.stringify(envIamUserKeySecret)) as Record<string, unknown>);
    // ### end iam user workaround ###

    if (secretsManagerSecretCreate) {
      const forProvider: { name: string; region: string; forceOverwriteReplicaSecret?: boolean } = {
        name: awsSecretName,
        region: region,
      };
      if (deletionPolicy === 'Delete') {
        forProvider.forceOverwriteReplicaSecret = true;
      }
      const annotations: Record<string, string> = {};
      if (secretsManagerSecretArn) {
        annotations['crossplane.io/external-name'] = secretsManagerSecretArn;
      }
      const smSecret = new Secret({
        metadata: {
          name: `${awsSecretName}-secretsmanager-secret`,
          ...(Object.keys(annotations).length > 0 ? { annotations } : {}),
        },
        spec: {
          deletionPolicy: deletionPolicy as 'Orphan' | 'Delete',
          forProvider: forProvider,
          providerConfigRef: { name: awsProviderConfigName },
        },
      });
      desiredComposed['secretsmanagerSecret'] = fromObject(JSON.parse(JSON.stringify(smSecret)) as Record<string, unknown>);
    }

    // Shared secret store mapped to secret on cloud-provider.
    const sharedSecretStoreManifest = {
      apiVersion: 'spaces.upbound.io/v1alpha1',
      kind: 'SharedSecretStore',
      metadata: {
        name: ctpName,
        namespace: groupName,
      },
      spec: {
        controlPlaneSelector: { names: [ctpName] },
        namespaceSelector: { names: [secretNamespace] },
        provider: {
          aws: {
            service: 'SecretsManager',
            region: region,
            auth: {
              secretRef: {
                accessKeyIDSecretRef: {
                  name: `${groupName}-secrets-read-access-key`,
                  key: 'username',
                },
                secretAccessKeySecretRef: {
                  name: `${groupName}-secrets-read-access-key`,
                  key: 'password',
                },
              },
            },
          },
        },
      },
    };
    const sharedSecretStore = {
      apiVersion: 'kubernetes.crossplane.io/v1alpha2',
      kind: 'Object',
      metadata: { name: `${ctpName}-sss` },
      spec: {
        deletionPolicy: deletionPolicy,
        watch: false,
        forProvider: { manifest: sharedSecretStoreManifest },
        providerConfigRef: { name: upboundProviderConfigName },
      },
    };
    desiredComposed['sharedSecretsStore'] = fromObject(sharedSecretStore as Record<string, unknown>);

    // Shared secret which will populate initial secret from cloud into the main
    // controlplane of the environment.

    // Build the externalSecretSpec, mirroring the spaces SharedExternalSecret
    // schema defaults (creationPolicy/deletionPolicy/conversionStrategy/etc).
    const targetTemplate: Record<string, unknown> = {};
    if (secretLabels && Object.keys(secretLabels).length > 0) {
      targetTemplate.metadata = { labels: secretLabels };
    }
    if (secretTemplateData !== undefined) {
      targetTemplate.data = secretTemplateData;
    }

    let target: Record<string, unknown>;
    if (Object.keys(targetTemplate).length > 0) {
      // Schema defaults applied when a template is present.
      const template: Record<string, unknown> = {
        engineVersion: 'v2',
        mergePolicy: 'Replace',
        ...targetTemplate,
      };
      target = {
        creationPolicy: 'Owner',
        deletionPolicy: 'Retain',
        name: externalSecretName,
        template: template,
      };
    } else {
      target = {
        creationPolicy: 'Owner',
        deletionPolicy: 'Retain',
        name: externalSecretName,
      };
    }

    const externalSecretSpec: Record<string, unknown> = {
      refreshInterval: '1m',
      secretStoreRef: {
        name: ctpName,
        kind: 'ClusterSecretStore',
      },
      target: target,
    };

    if (secretData !== undefined) {
      externalSecretSpec.data = secretData.map((entry) => {
        const remoteRef: Record<string, unknown> = {
          conversionStrategy: 'Default',
          decodingStrategy: 'None',
          metadataPolicy: 'None',
          ...entry.remoteRef,
        };
        const out: Record<string, unknown> = {
          secretKey: entry.secretKey,
          remoteRef: remoteRef,
        };
        if (entry.sourceRef !== undefined) {
          out.sourceRef = entry.sourceRef;
        }
        return out;
      });
    } else {
      externalSecretSpec.dataFrom = [
        {
          extract: {
            conversionStrategy: 'Default',
            decodingStrategy: 'None',
            key: awsSecretName,
            metadataPolicy: 'None',
          },
        },
      ];
    }

    const sharedExternalSecretManifest = {
      apiVersion: 'spaces.upbound.io/v1alpha1',
      kind: 'SharedExternalSecret',
      metadata: {
        name: externalSecretName,
        namespace: groupName,
      },
      spec: {
        controlPlaneSelector: { names: [ctpName] },
        namespaceSelector: { names: [secretNamespace] },
        externalSecretSpec: externalSecretSpec,
      },
    };
    const sharedExternalSecret = {
      apiVersion: 'kubernetes.crossplane.io/v1alpha2',
      kind: 'Object',
      metadata: { name: `${ctpName}-ses` },
      spec: {
        deletionPolicy: deletionPolicy,
        watch: false,
        forProvider: { manifest: sharedExternalSecretManifest },
        providerConfigRef: { name: upboundProviderConfigName },
      },
    };
    desiredComposed['sharedExternalSecret'] = fromObject(sharedExternalSecret as Record<string, unknown>);

    rsp = setDesiredComposedResources(rsp, desiredComposed);
    normal(rsp, 'Composed shared AWS secret resources');
    return rsp;
  }
}
