#!/usr/bin/env bash
set -aeuo pipefail

# Check if required variables are set
if [[ -z "$API_TOKEN" || -z "$ORGANIZATION" || -z "$CONTROLPLANE" || -z "$GROUP" || -z "$SPACE" ]]; then
  echo "Error: Missing required variables."
  echo "Please set the following variables: API_TOKEN, ORGANIZATION, CONTROLPLANE, GROUP, SPACE"
  exit 1
fi

cat <<EOF > configuration.yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: platform-ref-upbound
spec:
  package: xpkg.upbound.io/upbound/platform-ref-upbound:v0.1.0
EOF

# Create the YAML manifests
cat <<EOF > controlplane.yaml
apiVersion: spaces.upbound.io/v1beta1
kind: ControlPlane
metadata:
  name: $CONTROLPLANE
  namespace: $GROUP
spec:
  crossplane:
    version: 1.15.2-up.1
    autoUpgrade:
      channel: None
EOF

cat <<EOF > manifests.yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-token
  namespace: crossplane-system
type: Opaque
stringData:
  token: $API_TOKEN
---
apiVersion: v1
kind: Secret
metadata:
  name: default
  namespace: crossplane-system
type: Opaque
stringData:
  kubeconfig: |
    apiVersion: v1
    clusters:
    - cluster:
        insecure-skip-tls-verify: true
        server: https://$SPACE.space.mxe.upbound.io/apis/spaces.upbound.io/v1beta1/namespaces/$GROUP/controlplanes/$CONTROLPLANE/k8s
      name: upbound
    contexts:
    - context:
        cluster: upbound
        extensions:
        - extension:
            apiVersion: upbound.io/v1alpha1
            kind: SpaceExtension
            spec:
              cloud:
                organization: $ORGANIZATION
          name: spaces.upbound.io/space
        namespace: default
        user: upbound
      name: upbound
    current-context: upbound
    kind: Config
    preferences: {}
    users:
    - name: upbound
      user:
        exec:
          apiVersion: client.authentication.k8s.io/v1
          args:
          - organization
          - token
          command: up
          env:
          - name: ORGANIZATION
            value: $ORGANIZATION
          - name: UP_PROFILE
            value: default
          interactiveMode: IfAvailable
          provideClusterInfo: false
---
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      name: default
      namespace: crossplane-system
      key: kubeconfig
  identity:
    type: UpboundTokens
    source: Secret
    secretRef:
      name: api-token
      namespace: crossplane-system
      key: token
EOF

# Set context
up ctx upbound/$SPACE/

# Apply controlplane.yaml
kubectl apply -f controlplane.yaml

# Wait for the control plane to be ready
echo "Waiting for the ControlPlane to be ready..."
until kubectl get ctp $CONTROLPLANE -n $GROUP -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; do
  echo -n "."
  sleep 5
done

echo "ControlPlane $CONTROLPLANE in $GROUP hosted in $SPACE is ready."

# Set context
up ctx upbound/$SPACE/$GROUP/$CONTROLPLANE

# Apply
kubectl apply -f configuration.yaml
kubectl wait configuration.pkg --all --for=condition=Healthy --timeout 5m
kubectl wait configuration.pkg --all --for=condition=Installed --timeout 5m
kubectl wait configurationrevisions.pkg --all --for=condition=Healthy --timeout 5m
kubectl wait provider.pkg --all --for condition=Healthy --timeout 5m
kubectl wait function.pkg --all --for condition=Healthy --timeout 5m
kubectl apply -f manifests.yaml

rm -rf configuration.yaml
rm -rf manifests.yaml
rm -rf controlplane.yaml
