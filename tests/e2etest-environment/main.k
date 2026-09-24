"""
End-to-end test for the Environment API.

Provisions a real Upbound group and control plane through the Spaces API, and real AWS IAM
and Secrets Manager resources, then asserts the Environment XR reaches Ready.

Run it with:

    export UP_E2E_API_TOKEN=...      # Upbound token; needs group/control-plane create rights
    export UP_E2E_ORG=solutions
    export UP_E2E_GROUP=default
    export UP_E2E_SPACE_HOST=upbound-aws-us-east-1.spaces.upbound.io
    up test run tests/e2etest-environment --e2e

`file.read_env` is how a value reaches a KCL test module - manifest generation runs in a
container and only UP_-prefixed variables are forwarded into it. Every read below fails loudly
on an unset variable rather than generating a manifest with an empty credential in it.
"""

import file
import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesm
import models.io.k8s.api.core.v1 as corev1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.sa.v1 as sav1

_mustEnv = lambda name: str -> str {
    """Read a UP_-prefixed variable, failing generation rather than emitting an empty value."""
    _v = file.read_env(name)
    assert _v != "" and _v != Undefined and _v != None, "${name} must be set to run this e2e test"
    _v
}

_token     = _mustEnv("UP_E2E_API_TOKEN")
_org       = _mustEnv("UP_E2E_ORG")
_group     = _mustEnv("UP_E2E_GROUP")
_spaceHost = _mustEnv("UP_E2E_SPACE_HOST")

# The composition learns the Space it lives in by observing this Secret and regex-parsing the
# server URL, so the URL shape is load-bearing: the 5th path segment becomes bootstrapGroup and
# the 7th becomes bootstrapCtp. "bootstrap" here is arbitrary - it only has to match the
# ProviderConfig named "<bootstrapCtp>-ctp" that we create below.
_bootstrapKubeconfig = """apiVersion: v1
kind: Config
current-context: upbound
preferences: {}
clusters:
- name: upbound
  cluster:
    insecure-skip-tls-verify: true
    server: https://${_spaceHost}/apis/spaces.upbound.io/v1beta1/namespaces/${_group}/controlplanes/bootstrap/k8s
contexts:
- name: upbound
  context:
    cluster: upbound
    namespace: default
    user: upbound
    extensions:
    - name: spaces.upbound.io/space
      extension:
        apiVersion: upbound.io/v1alpha1
        kind: SpaceExtension
        spec:
          cloud:
            organization: ${_org}
users:
- name: upbound
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1
      command: up
      args: [organization, token]
      interactiveMode: IfAvailable
      provideClusterInfo: false
      env:
      - name: ORGANIZATION
        value: ${_org}
"""

_items = [
    metav1alpha1.E2ETest{
        metadata.name: "environment"
        spec = {
            crossplane = {
                # Pinned: v2 is required for the namespaced XRDs, and Stable can still
                # resolve to the v1 line.
                autoUpgrade.channel = "None"
                version = "2.4.1-up.1"
            }
            defaultConditions = ["Ready"]

            # Applied before the package installs. Both providers are declared here rather
            # than left to dependency resolution, so that each is bound to its
            # DeploymentRuntimeConfig from the moment it starts - neither default works
            # against Upbound Spaces. See README step 5 for why.
            #
            # enable-management-policies is temporary: upbound/provider-upbound#41 flips that
            # default and is merged, but unreleased as of v1.1.1. Drop it, and the Provider
            # override with it, once a release containing the fix is pinned below.
            # disable-server-side-apply is permanent - SSA is the right default for
            # provider-kubernetes, and the Spaces API gateway is the exception.
            initResources = [
                # Plain dicts: this project generates no models for the pkg.crossplane.io
                # API group, and adding an apiDependency just for two literals is not worth it.
                {
                    apiVersion = "pkg.crossplane.io/v1beta1"
                    kind = "DeploymentRuntimeConfig"
                    metadata.name = "enable-management-policies"
                    spec.deploymentTemplate.spec = {
                        selector = {}
                        template.spec.containers = [{
                            name = "package-runtime"
                            env = [{name = "ENABLE_MANAGEMENT_POLICIES", value = "true"}]
                        }]
                    }
                }
                {
                    apiVersion = "pkg.crossplane.io/v1beta1"
                    kind = "DeploymentRuntimeConfig"
                    metadata.name = "disable-server-side-apply"
                    spec.deploymentTemplate.spec = {
                        selector = {}
                        template.spec.containers = [{
                            name = "package-runtime"
                            env = [{name = "ENABLE_SERVER_SIDE_APPLY", value = "false"}]
                        }]
                    }
                }
                {
                    apiVersion = "pkg.crossplane.io/v1"
                    kind = "Provider"
                    metadata.name = "upbound-provider-upbound"
                    spec = {
                        package = "xpkg.upbound.io/upbound/provider-upbound:v1.1.1"
                        runtimeConfigRef = {
                            apiVersion = "pkg.crossplane.io/v1beta1"
                            kind = "DeploymentRuntimeConfig"
                            name = "enable-management-policies"
                        }
                    }
                }
                {
                    apiVersion = "pkg.crossplane.io/v1"
                    kind = "Provider"
                    metadata.name = "upbound-provider-kubernetes"
                    spec = {
                        package = "xpkg.upbound.io/upbound/provider-kubernetes:v1.3.3"
                        runtimeConfigRef = {
                            apiVersion = "pkg.crossplane.io/v1beta1"
                            kind = "DeploymentRuntimeConfig"
                            name = "disable-server-side-apply"
                        }
                    }
                }
            ]

            extraResources = [
                corev1.Secret{
                    metadata = {name = "bootstrap-token", namespace = "default"}
                    type = "Opaque"
                    stringData = {token = _token}
                }
                corev1.Secret{
                    metadata = {name = "bootstrap-kubeconfig", namespace = "default"}
                    type = "Opaque"
                    stringData = {kubeconfig = _bootstrapKubeconfig}
                }
                # InjectedIdentity: this ProviderConfig only has to read the Secret above off
                # the test's own control plane, so it needs no kubeconfig - which is just as
                # well, since that control plane's name is not known when this is generated.
                kubernetesm.ProviderConfig{
                    metadata = {name = "bootstrap-ctp", namespace = "default"}
                    spec.credentials.source = "InjectedIdentity"
                }
            ]

            manifests = [
                sav1.Environment{
                    metadata = {name = "e2e", namespace = "default"}
                    spec.parameters = {
                        # Delete, not Orphan: a CI suite has to clean up after itself.
                        deletionPolicy = "Delete"
                        aws = {
                            accountId = "609897127049"
                            region = "eu-central-1"
                            # Web identity - no AWS credential is stored anywhere. The role
                            # trust must allow this test's control plane OIDC subject,
                            # mcp:<org>/<project>-uptest-environment:provider:provider-aws.
                            roleArn = "arn:aws:iam::609897127049:role/solutions-e2e-provider-aws"
                            providerRole = {
                                # Adopt the account-wide provider rather than trying to create
                                # a second one, which AWS forbids. The composition orphans an
                                # adopted provider regardless of deletionPolicy, so teardown
                                # deletes the Role and its attachment but leaves this alone -
                                # see test-environment-adopted-oidc-is-orphaned.
                                oidcProviderArn = "arn:aws:iam::609897127049:oidc-provider/proidc.upbound.io"
                            }
                            sharedSecret = {}
                        }
                        upbound = {
                            initKubeconfigSecretRef = {name = "bootstrap-kubeconfig", namespace = "default"}
                            tokenSecretRef = {name = "bootstrap-token", namespace = "default"}
                            # No Argo CD on an ephemeral control plane, and the registration
                            # Secret targets an `argocd` namespace that will not exist.
                            createArgoSecret = False
                        }
                    }
                }
            ]

            # Provisioning a control plane plus IAM and Secrets Manager takes a while, and
            # teardown has to delete them all again.
            timeoutSeconds = 3600
            cleanupTimeoutSeconds = 1800
            skipDelete = False
        }
    }
]

items = _items
