# Bootstrap Configuration Package

This Crossplane configuration package enables bootstrapping of Upbound Spaces environments with AWS integration through a declarative GitOps approach.

## Overview

The Bootstrap Configuration Package provides an `XEnvironment` custom resource that automates the creation and management of:

- Upbound Control Planes in Spaces
- AWS IAM roles and permissions
- Cross-service authentication with OIDC
- Secret management between AWS and Upbound
- Provider configurations for Kubernetes resources
- Teams, robots, and robot tokens for automation

## Features

- **Declarative Environment Management**: Define your entire environment as code
- **AWS Integration**: Automated setup of IAM roles, policies, and OIDC authentication
- **Secret Management**: Secure transfer of credentials between AWS and Upbound
- **Team & Robot Automation**: Create teams, robots, and tokens for automated workflows
- **GitOps Ready**: Designed for continuous delivery workflows
- **Optional Components**: Flexibility to enable/disable specific features as needed:
  - AWS Provider Role with OIDC
  - AWS Secrets Manager integration
  - Upbound Team with Robot setup

## Usage

### Prerequisites

- Upbound account with appropriate permissions
- Access to an AWS account
- kubectl CLI installed and configured

### Installation

1. Create a group and a controlplane on upbound

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

# Create controlplane
up ctp create "${UPBOUND_CTP}" --crossplane-channel="Rapid"

# Check status of controlplane (should show Healthy: True)
up ctp list

# Switch context to control-plane (might take a minute to become ready)
up ctx "${UPBOUND_ORG}/${UPBOUND_SPACE}/${UPBOUND_GROUP}/${UPBOUND_CTP}"
```

2. Create personal access token for upbound

   *The token enables API authentication with Upbound services. This will be used by Crossplane providers to interact with your control planes.*

- Navigate to `https://console.upbound.io/`
- Choose your organization and click on "Console"
- Click on your user in the upper right corner
- Click on "My Account"
- Click on "API Tokens" on the left navigation
- Click "Create New Token"
- Enter a name for your token and click on "Create Token"
- Copy the Token (Access ID is not needed for our case)

3. Create kubernetes secrets for the token

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

4. Create kubeconfig for provider-kubernetes

   *This creates a special kubeconfig that allows Crossplane's Kubernetes provider to interact with your control plane. It references the token created in the previous step.*

```bash
up ctx . -f - > kubeconfig.yaml
kubectl -n default create secret generic bootstrap-kubeconfig --from-file=kubeconfig=kubeconfig.yaml
```

5. Install the configuration:

   *This installs the bootstrap configuration package into your control plane. The configuration contains the XEnvironment CRD and composition function that automate environment setup.*

```bash
cat <<EOF | kubectl apply -f -
  apiVersion: pkg.crossplane.io/v1
  kind: Configuration
  metadata:
    name: configuration-upbound-bootstrap
  spec:
    package: xpkg.upbound.io/solutions/configuration-upbound-bootstrap:v0.0.0-1741685797
EOF
```

6. Create provider config for provider-kubernetes

   *This configures the Kubernetes provider to use your kubeconfig and token from the earlier steps, enabling it to create resources in your control plane.*

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

8. Create an XEnvironment resource:

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
          # secretsManagerSecretArn: "arn:aws:secretsmanager:region:your_accountid:secret:example-config-abcde"
      upbound:
        initKubeconfigSecretRef:
          name: bootstrap-kubeconfig
        tokenSecretRef:
          name: bootstrap-token
        # Optional: Creates a team with associated robot and token when specified
        teamWithRobot: {}
EOF
```

## Architecture

![Architecture Diagram](./assets/arch.svg)

## Optional Component Configuration

### AWS Components

The following AWS components can be optionally configured or omitted:

#### Provider Role with OIDC

When the `providerRole` parameter is specified:
- If specified as an empty object (`providerRole: {}`), a new OIDC provider and IAM role will be created
- To use an existing OIDC provider, specify its ARN: `providerRole: { oidcProviderArn: "arn:aws:..." }`

#### Secrets Manager Integration

When the `sharedSecret` parameter is specified:
- If specified as an empty object (`sharedSecret: {}`), a new AWS Secrets Manager secret will be created
- To use an existing secret, specify its ARN: `sharedSecret: { secretsManagerSecretArn: "arn:aws:..." }`

### Upbound Components

#### Teams, Robots, and Tokens

When the `teamWithRobot` parameter is specified (even as an empty object), the bootstrap configuration automatically creates:

1. **Team** - A dedicated team for the environment with the same name as the environment group
2. **Robot** - A service account robot associated with your organization
3. **Robot Token** - A token for the robot to authenticate with Upbound APIs
4. **Robot Team Membership** - Associates the robot with the team for proper permissions
5. **Admin Role Binding** - Grants the team admin rights on the environment group

These resources enable automation through GitOps and CI/CD pipelines, allowing programmatic interaction with control planes. The team structure ensures proper access control and permission management for your environment.

If you don't need team and robot resources, simply omit the `teamWithRobot` parameter from your XEnvironment specification.

## Caveats

### External models

External models (like for provider-upbound and upbound spaces) are imported with `kcl import -m crd crd.yaml` from kubernetes crds.
Imports need to be fixed after crd import to `import ..k8s.apimachinery.pkg.apis.meta.v1`

## Development

### Testing

The repository includes multiple test configurations:

- Basic functionality tests: `tests/test-xenvironment/`
- Deletion policy tests: `tests/test-xenvironment-deletion-policy-delete/`
- No cloud provider resources: `tests/test-xenvironment-no-cloudprovider-resource/`

To run tests:

```bash
up test run tests/test-*
```
