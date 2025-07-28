# Platform Reference Upbound 
![IDP Hero](assets/platform-ref-upbound-hero.png)
This Upbound project enables declarative bootstrapping of Upbound Spaces environments with Cloud Provider integration through a GitOps approach.

# Table of Contents
- [💡 Overview](#-overview)
- [🛠 Prerequisites](#-prerequisites)
- [💻 Getting Started](#-getting-started)
- [🏗️ Architecture](#-architecture)
- [🔧 Optional Component Configuration](#-optional-component-configuration)
- [🔐 XSharedAWSSecret](#-xsharedawssecret)
- [💜 XUpboundRepoSet](#-xupboundreposet)
- [🐛 Development](#-development)


## 💡 Overview

### This repository:
- **Declarative Environment Management**: Defines your entire environment as code via `XEnvironment`, `XSharedAWSSecret`, and `XUpboundRepoSet` resources
- **AWS Integration**: Automatically sets up IAM roles, policies, and OIDC authentication
- **Secret Management**: Securely transfers credentials between AWS and Upbound via dedicated `XSharedAWSSecret` composition
- **Bootstrap Secret Synchronization**: Copies secrets from bootstrap control plane to target environments
- **Team & Robot Automation**: Creates teams, robots, and tokens for automated workflows
- **Repository Management**: Creates and configures Upbound repositories with team permissions and robot access
- **GitOps Ready**: Designed for continuous delivery workflows
- **Optional Components**: Flexibility to enable/disable specific features as needed:
  - AWS Provider Role with OIDC
  - AWS Secrets Manager integration
  - Upbound Team with Robot setup
  - Bootstrap secret synchronization


### What does `XEnvironment` Resource do?
- Upbound Control Planes in Spaces
- AWS IAM roles and permissions
- Cross-service authentication with OIDC
- Secret management between AWS and Upbound
- Secret synchronization from bootstrap control plane to environment
- Provider configurations for Kubernetes resources
- Teams, robots, and robot tokens for automation

### What does `XUpboundRepoSet` Resource do?
- Upbound repositories creation and configuration
- Team-based permission management for repositories
- Consistent repository configuration across your organization


## 🛠 Prerequisites
* [An Upbound Account](https://www.upbound.io/register/a) with appropriate permissions
*  Access to AWS account
*  `kubectl` CLI installed and configured
* [Upbound CLI (`up`)](https://docs.upbound.io/cli/)


## 💻 Getting Started

1. Create a Group and Control Plane on Upbound

   *This step establishes your Upbound organizational structure. The group organizes your control planes, and the control plane is where Crossplane will run to manage your infrastructure.*

```bash
UPBOUND_ORG="your_upbound_org"
# Other spaces are available, check with `up ctx`
UPBOUND_SPACE="upbound-gcp-us-west-1"
UPBOUND_GROUP="my-group"
UPBOUND_CTP="bootstrap"

# Login and switch context
up login -a $UPBOUND_ORG --profile $UPBOUND_ORG
up ctx "${UPBOUND_ORG}/${UPBOUND_SPACE}"

# Create group
up group create "${UPBOUND_GROUP}"

# Switch context to group
up ctx "${UPBOUND_ORG}/${UPBOUND_SPACE}/${UPBOUND_GROUP}"

# Create control plane
up ctp create "${UPBOUND_CTP}" --crossplane-channel="Rapid"

# Check status of control plane (should show Healthy: True)
up ctp list

# Switch context to control plane (might take a minute to become ready)
up ctx "${UPBOUND_ORG}/${UPBOUND_SPACE}/${UPBOUND_GROUP}/${UPBOUND_CTP}"
```

2. Create personal access token for Upbound

   *The token enables API authentication with Upbound services. This will be used by Crossplane providers to interact with your control planes.*

- Navigate to `https://console.upbound.io/`
- Choose your organization and click on "Console"
- Click on your user profile in the upper right corner
- Click on "My Account"
- Select "API Tokens" from the left navigation
- Click "Create New Token"
- Enter a name for your token and click "Create Token"
- Copy the Token value (Access ID is not needed for this use case)

3. Create Kubernetes secrets for the token

   *This step stores your Upbound token securely in Kubernetes as a secret, allowing your resources to authenticate with Upbound.*

```bash
TOKEN="Paste token here!"

cat <<EOF | kubectl apply -f -
  apiVersion: v1
  kind: Secret
  metadata:
    name: bootstrap-token
    namespace: default
  type: Opaque
  stringData:
    token: ${TOKEN}
EOF
```

4. Create `kubeconfig` for provider-kubernetes

   *This creates a special `kubeconfig` that allows Crossplane's Kubernetes provider to interact with your control plane. It references the token created in the previous step.*

```bash
up ctx . -f - > kubeconfig.yaml
kubectl -n default create secret generic bootstrap-kubeconfig --from-file=kubeconfig=kubeconfig.yaml
```

5. Install the configuration:

   *This installs the bootstrap configuration package into your control plane. The configuration contains the `XEnvironment` CRD and composition function that automate environment setup.*

```bash
VERSION=""

cat <<EOF | kubectl apply -f -
  apiVersion: pkg.crossplane.io/v1
  kind: Configuration
  metadata:
    name: platform-ref-upbound
  spec:
    package: xpkg.upbound.io/upbound/platform-ref-upbound:"${VERSION}"
EOF
```

6. Create provider config for provider-kubernetes

   *This configures the Kubernetes provider to use your `kubeconfig` and token from the earlier steps, enabling it to create resources in your control plane.*

```bash
cat <<EOF | kubectl apply -f -
  apiVersion: kubernetes.crossplane.io/v1alpha1
  kind: ProviderConfig
  metadata:
    name: ${UPBOUND_CTP}-ctp
  spec:
    credentials:
      source: Secret
      secretRef:
        name: bootstrap-kubeconfig
        namespace: default
        key: kubeconfig
    identity:
      type: UpboundTokens
      source: Secret
      secretRef:
        name: bootstrap-token
        namespace: default
        key: token
EOF
```

7. Configure credentials for provider-aws (option 1, static credentials)

   *This creates a secret containing your AWS credentials, allowing the AWS provider to authenticate with AWS services.*

```bash
SECRET_PATH=path/to/aws/credentials
kubectl create secret generic "aws-creds" -n default --from-file=credentials="${SECRET_PATH}"
```

8. Create an `XEnvironment` resource:

   *Finally, this creates the XEnvironment resource that ties everything together. This triggers the composition function to create all the necessary resources in both AWS and Upbound to establish your environment.*

```bash
AWS_ACCOUNT_ID="your_accountid"
AWS_REGION="us-east-1"

cat <<EOF | kubectl apply -f -
  apiVersion: sa.upbound.io/v1
  kind: XEnvironment
  metadata:
    name: example
  spec:
    parameters:
      aws:
        accountId: "${AWS_ACCOUNT_ID}"
        credsSecretRef:
          name: aws-creds
          namespace: default
        region: "${AWS_REGION}"
        # Empty objects will create new resources
        # To use existing resources, specify ARNs as shown in the commented values
        providerRole: {}
          # oidcProviderArn: "arn:aws:iam::your_accountid:oidc-provider/proidc.upbound.io"
        sharedSecret: {}
          # secretsManagerSecret:
              # arn: "arn:aws:secretsmanager:region:your_accountid:secret:example-config-abcde"
      upbound:
        initKubeconfigSecretRef:
          name: bootstrap-kubeconfig
        tokenSecretRef:
          name: bootstrap-token
        # Optional: Creates a team with associated robot and token when specified
        teamWithRobot: {}
        # Optional: Synchronize secrets from bootstrap control plane to this environment
        secretSync:
          - sourceRef:
              name: source-secret-name
              namespace: default
            destRef:
              name: destination-secret-name
              namespace: default
EOF
```

## 🏗️ Architecture

![Architecture Diagram](./assets/arch.svg)

## 🔧 Optional Component Configuration

### AWS Components

The following AWS components can be optionally configured or omitted:

#### Provider Role with OIDC

When the `providerRole` parameter is specified:
- If specified as an empty object (`providerRole: {}`), a new OIDC provider and IAM role will be created
- To use an existing OIDC provider, specify its ARN: `providerRole: { oidcProviderArn: "arn:aws:..." }`

#### Secrets Manager Integration

When the `sharedSecret` parameter is specified:
- If specified as an empty object (`sharedSecret: {}`), a new AWS Secrets Manager secret will be created
- To use an existing secret, specify its ARN: `sharedSecret: { arn: "arn:aws:..." }`
- To add labels to the target secret: `sharedSecret: { externalSecret: { spec: { target: { template: { metadata: { labels: { app: "my-app", environment: "prod" } } } } } } }`
- To control the target namespace: `sharedSecret: { externalSecret: { namespace: "my-namespace" } }`

#### ArgoCD Integration

XEnvironment automatically creates ArgoCD cluster secrets for GitOps deployments. Set `createArgoSecret: false` to disable (default: `true`).

**Generated Secret:**
- **Location**: `argocd` namespace  
- **Name**: `{group}-{controlplane}`
- **Authentication**: Uses Upbound CLI (`up org token`) with your access token
- **Server**: Points to your control plane's Kubernetes API endpoint

This enables ArgoCD to authenticate and manage applications across your Upbound Spaces control planes.

### Upbound Components

#### Secret Synchronization

When the `secretSync` parameter is specified, the bootstrap configuration copies secrets from the bootstrap control plane to the target environment control plane. This feature is useful for sharing robot tokens with CI environments and making secrets created in the bootstrap context available in the new environment.

Example configuration:
```yaml
secretSync:
  - sourceRef:
      name: source-secret-name
      namespace: default
    destRef:
      name: destination-secret-name
      namespace: default
```

#### Teams, Robots, and Tokens

When the `teamWithRobot` parameter is specified (even as an empty object), the bootstrap configuration automatically creates:

1. **Team** - A dedicated team for the environment with the same name as the environment group
2. **Robot** - A service account robot associated with your organization
3. **Robot Token** - A token for the robot to authenticate with Upbound APIs
4. **Robot Team Membership** - Associates the robot with the team for proper permissions
5. **Admin Role Binding** - Grants the team admin rights on the environment group

These resources enable automation through GitOps and CI/CD pipelines, allowing programmatic interaction with control planes. The team structure ensures proper access control and permission management for your environment.

If you don't need team and robot resources, simply omit the `teamWithRobot` parameter from your XEnvironment specification.

## 🔐 XSharedAWSSecret

The `XSharedAWSSecret` custom resource provides a dedicated composition for managing AWS Secrets Manager integration with Upbound Spaces.

### Usage

The `XSharedAWSSecret` is automatically created by `XEnvironment` when the `sharedSecret` parameter is specified, but can also be used as a standalone resource:

```yaml
apiVersion: sa.upbound.io/v1
kind: XEnvironment
metadata:
  name: example
spec:
  parameters:
    aws:
      sharedSecret: {}  # Creates XSharedAWSSecret automatically
      # or specify existing secret ARN:
      # sharedSecret:
      #   arn: "arn:aws:secretsmanager:region:account:secret:name"
```

### Standalone Usage

```yaml
apiVersion: sa.upbound.io/v1
kind: XSharedAWSSecret
metadata:
  name: example-shared-secret
spec:
  parameters:
    deletionPolicy: Orphan
    aws:
      accountId: "123456789012"
      region: us-east-1
      secretsManagerSecret:
        arn: "arn:aws:secretsmanager:us-east-1:123456789012:secret:example-config-AbCdEf"
        name: "custom-secret-name"  # Optional: overrides namePrefix logic
        create: false              # Optional: skip creation for existing secrets
      namePrefix: example-env
      providerConfigRef:
        name: example-env
    upbound:
      group: example-env           # Renamed from groupName
      controlPlane: example-ctp    # Renamed from controlPlaneName
      providerConfigRef:
        name: example-env-group
    externalSecret:
      name: custom-external-secret # Optional: Name for the SharedExternalSecret (defaults to control plane name)
      namespace: my-namespace      # Optional: Namespace for the target secret
      spec:
        # Optional: Specify individual secret keys to extract (takes precedence over bulk extraction)
        data:
          - secretKey: githubAppPrivateKey
            remoteRef:
              key: example-config
              property: githubAppPrivateKey
          - secretKey: databaseUrl
            remoteRef:
              key: example-config
              property: databaseUrl
              decodingStrategy: Base64
        target:
          template:
            metadata:
              labels:              # Optional: Labels for the target secret
                app: my-application
                environment: production
            data:                  # Optional: Template data with expressions for the target secret
              githubAppID: '{{ $creds := .githubCreds | fromJson }}{{ index $creds.app_auth 0 "id" }}'
              url: '{{ $creds := .githubCreds | fromJson }}https://github.com/{{ $creds.owner }}'
              type: "git"
```

### Key Features

- **Custom Secret Names**: Use `secretsManagerSecret.name` to override the default `namePrefix-config` naming pattern
- **Skip Creation**: Set `secretsManagerSecret.create: false` to use existing AWS secrets without creating new ones
- **IAM Name Truncation**: Automatically handles AWS IAM's 64-character limit by intelligently truncating names while preserving meaningful prefixes
- **Updated Parameter Names**: Uses `group` and `controlPlane` instead of `groupName` and `controlPlaneName`
- **Secret Labels**: Add custom labels to the target secret created by SharedExternalSecret using `externalSecret.spec.target.template.metadata.labels`
- **Secret Namespace**: Control the namespace where the target secret is deployed using `externalSecret.namespace`
- **Granular Secret Data**: Use `externalSecret.spec.data` for individual key-value extraction with property-specific settings (takes precedence over bulk extraction)
- **Template Data**: Use `externalSecret.spec.target.template.data` to add templated data transformations with External Secrets templating expressions

### What XSharedAWSSecret creates:
- IAM user with read permissions for Secrets Manager
- IAM policy with appropriate permissions (auto-truncated names for long secrets)
- AWS Secrets Manager secret (conditionally created based on `create` parameter)
- SharedSecretStore for External Secrets Operator
- SharedExternalSecret for syncing secrets to control planes
- Kubernetes secrets for IAM credentials

### IAM Resource Naming

When secret names are very long, IAM resource names are automatically truncated to stay within AWS's 64-character limit. The truncation preserves as much of the meaningful prefix as possible and appends a hash for uniqueness:

```
Original: very-long-secret-name-that-exceeds-sixty-four-characters-secrets-read
Truncated: very-long-secret-name-that-exceeds-12345678-secrets-read
```

## 💜 XUpboundRepoSet

The `XUpboundRepoSet` custom resource allows you to manage Upbound repositories and their permissions declaratively.

### Usage Example

```yaml
apiVersion: sa.upbound.io/v1
kind: XUpboundRepoSet
metadata:
  name: example
spec:
  parameters:
    organization: your-organization
    permissions:
      teams:
        your-team-name:
          permission: write
    repositories:
      repo-name-1: {}
      repo-name-2: {}
    tokenSecretRef:
      name: your-token-secret
      namespace: default
      key: token
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `organization` | The Upbound organization name |
| `permissions.teams` | Map of team names to permission objects (with permission type: "read", "write", "admin") |
| `repositories` | Map of repository names to empty objects |
| `tokenSecretRef` | Reference to a Kubernetes secret containing the Upbound token |
| `tokenSecretRef.name` | Name of the secret |
| `tokenSecretRef.namespace` | Namespace for the secret (defaults to "default") |
| `tokenSecretRef.key` | Key in the secret (defaults to "token") |

## 🐛 Development

### Testing

The repository includes multiple test configurations:

- Basic functionality tests: `tests/test-xenvironment/`
- Deletion policy tests: `tests/test-xenvironment-deletion-policy-delete/`
- No cloud provider resources: `tests/test-xenvironment-no-cloudprovider-resource/`
- XSharedAWSSecret tests: `tests/test-xsharedawssecret/`

To run tests:

```bash
up test run tests/test-*
```
