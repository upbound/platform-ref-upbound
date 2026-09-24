import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesm
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import base64
import models.io.upbound.sa.v1 as sav1


_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-environment-no-cloudprovider-resource"
        spec = {
            assertResources: [
                kubernetesm.Object{
                    metadata: {
                        name: "example-ctp-kubeconfig"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        forProvider: {
                            manifest: {
                                apiVersion: "v1"
                                kind: "Secret"
                                metadata: {
                                    name: "example-ctp-kubeconfig"
                                    namespace: "default"
                                }
                                data : {
                                    kubeconfig : base64.encode("{'apiVersion': 'v1', 'clusters': [{'cluster': {'insecure-skip-tls-verify': True, 'server': 'https://upbound-aws-us-east-1.space.mxe.upbound.io/apis/spaces.upbound.io/v1beta1/namespaces/solutions-non-prod-example/controlplanes/example/k8s'}, 'name': 'upbound'}], 'contexts': [{'context': {'cluster': 'upbound', 'extensions': [{'extension': {'apiVersion': 'upbound.io/v1alpha1', 'kind': 'SpaceExtension', 'spec': {'cloud': {'organization': 'upbound'}}}, 'name': 'spaces.upbound.io/space'}], 'namespace': 'default', 'user': 'upbound'}, 'name': 'upbound'}], 'current-context': 'upbound', 'kind': 'Config', 'preferences': {}, 'users': [{'name': 'upbound', 'user': {'exec': {'apiVersion': 'client.authentication.k8s.io/v1', 'args': [organization, token], 'command': 'up', 'env': [{'name': 'ORGANIZATION', 'value': 'upbound'}, {'name': 'UP_PROFILE', 'value': 'default'}], 'interactiveMode': 'IfAvailable', 'provideClusterInfo': False}}}]}")
                                }
                            }
                        }
                        providerConfigRef: {
                            kind: "ProviderConfig"
                            name: "bootstrap-ctp"
                        }
                        watch: False
                    }
                }
                kubernetesm.Object{
                    metadata: {
                        name: "example-ctp"
                    }
                    spec: {
                        readiness: {
                            policy: "DeriveFromObject"
                        }
                        managementPolicies: ["Create", "Observe", "Update", "LateInitialize"]
                        forProvider: {
                            manifest: {
                                apiVersion: "spaces.upbound.io/v1beta1"
                                kind: "ControlPlane"
                                metadata: {
                                    name: "example"
                                    namespace: "solutions-non-prod-example"
                                }
                                spec: {
                                    class: "default"
                                    crossplane: {
                                        autoUpgrade: {
                                            channel: "Rapid"
                                        }
                                    }
                                }
                            }
                        }
                        watch: False
                    }
                }
                kubernetesm.Object{
                    metadata = {
                        name = "solutions-non-prod-example-group-kubeconfig"
                    }
                    spec = {
                        forProvider = {
                            manifest = {
                                apiVersion = "v1"
                                kind = "Secret"
                                metadata = {
                                    name = "solutions-non-prod-example-group-kubeconfig"
                                    namespace = "default"
                                }
                                data = {
                                    kubeconfig = base64.encode("{'apiVersion': 'v1', 'clusters': [{'cluster': {'insecure-skip-tls-verify': True, 'server': 'https://upbound-aws-us-east-1.space.mxe.upbound.io'}, 'name': 'upbound'}], 'contexts': [{'context': {'cluster': 'upbound', 'extensions': [{'extension': {'apiVersion': 'upbound.io/v1alpha1', 'kind': 'SpaceExtension', 'spec': {'cloud': {'organization': 'upbound'}}}, 'name': 'spaces.upbound.io/space'}], 'namespace': 'solutions-non-prod-example', 'user': 'upbound'}, 'name': 'upbound'}], 'current-context': 'upbound', 'kind': 'Config', 'preferences': {}, 'users': [{'name': 'upbound', 'user': {'exec': {'apiVersion': 'client.authentication.k8s.io/v1', 'args': [organization, token], 'command': 'up', 'env': [{'name': 'ORGANIZATION', 'value': 'upbound'}, {'name': 'UP_PROFILE', 'value': 'default'}], 'interactiveMode': 'IfAvailable', 'provideClusterInfo': False}}}]}")
                                }
                            }
                        }
                        managementPolicies = ["*"]
                        providerConfigRef = {
                            kind = "ProviderConfig"
                            name = "bootstrap-ctp"
                        }
                        watch = False
                    }
                }
                kubernetesm.ProviderConfig{
                    metadata = {
                        name = "example-ctp"
                    }
                    spec = {
                        credentials = {
                            secretRef = {
                                key = "kubeconfig"
                                name = "example-ctp-kubeconfig"
                                namespace = "default"
                            }
                            source = "Secret"
                        }
                        identity = {
                            secretRef = {
                                key = "token"
                                name = "upbound-token"
                                namespace = "default"
                            }
                            source = "Secret"
                            $type = "UpboundTokens"
                        }
                    }
                }
               kubernetesm.ProviderConfig{
                    metadata = {
                        name = "solutions-non-prod-example-group"
                    }
                    spec = {
                        credentials = {
                            secretRef = {
                                key = "kubeconfig"
                                name = "solutions-non-prod-example-group-kubeconfig"
                                namespace = "default"
                            }
                            source = "Secret"
                        }
                        identity = {
                            secretRef = {
                                key = "token"
                                name = "upbound-token"
                                namespace = "default"
                            }
                            source = "Secret"
                            $type = "UpboundTokens"
                        }
                    }
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata = {
                        name = "example-space-kubeconfig"
                    }
                    spec = {
                        replayDeletion = True
                        of = {
                            apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                            kind = "Object"
                            resourceRef = {
                                name = "example-space-kubeconfig"
                            }
                        }
                        by = {
                            apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                            kind = "ProviderConfig"
                            resourceRef = {
                                name = "example-space"
                            }
                        }
                    }
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata = {
                        name = "solutions-non-prod-example-group-kubeconfig"
                    }
                    spec = {
                        replayDeletion = True
                        of = {
                            apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                            kind = "Object"
                            resourceRef = {
                                name = "solutions-non-prod-example-group-kubeconfig"
                            }
                        }
                        by = {
                            apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                            kind = "ProviderConfig"
                            resourceRef = {
                                name = "solutions-non-prod-example-group"
                            }
                        }
                    }
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata = {
                        name = "example-ctp-kubeconfig"
                    }
                    spec = {
                        replayDeletion = True
                        of = {
                            apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                            kind = "Object"
                            resourceRef = {
                                name = "example-ctp-kubeconfig"
                            }
                        }
                        by = {
                            apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                            kind = "ProviderConfig"
                            resourceRef = {
                                name = "example-ctp"
                            }
                        }
                    }
                }
                kubernetesm.Object{
                    metadata = {
                        name = "example-space-kubeconfig"
                    }
                    spec = {
                        forProvider = {
                            manifest = {
                                apiVersion = "v1"
                                kind = "Secret"
                                metadata = {
                                    name = "example-space-kubeconfig"
                                    namespace = "default"
                                }
                                data = {
                                    kubeconfig = base64.encode("{'apiVersion': 'v1', 'clusters': [{'cluster': {'insecure-skip-tls-verify': True, 'server': 'https://upbound-aws-us-east-1.space.mxe.upbound.io'}, 'name': 'upbound'}], 'contexts': [{'context': {'cluster': 'upbound', 'extensions': [{'extension': {'apiVersion': 'upbound.io/v1alpha1', 'kind': 'SpaceExtension', 'spec': {'cloud': {'organization': 'upbound'}}}, 'name': 'spaces.upbound.io/space'}], 'namespace': 'default', 'user': 'upbound'}, 'name': 'upbound'}], 'current-context': 'upbound', 'kind': 'Config', 'preferences': {}, 'users': [{'name': 'upbound', 'user': {'exec': {'apiVersion': 'client.authentication.k8s.io/v1', 'args': [organization, token], 'command': 'up', 'env': [{'name': 'ORGANIZATION', 'value': 'upbound'}, {'name': 'UP_PROFILE', 'value': 'default'}], 'interactiveMode': 'IfAvailable', 'provideClusterInfo': False}}}]}")
                                }
                            }
                        }
                        managementPolicies = ["*"]
                        providerConfigRef = {
                            kind = "ProviderConfig"
                            name = "bootstrap-ctp"
                        }
                        watch = False
                    }
                }

                kubernetesm.ProviderConfig{
                    metadata = {
                        name = "example-space"
                    }
                    spec = {
                        credentials = {
                            secretRef = {
                                key = "kubeconfig"
                                name = "example-space-kubeconfig"
                                namespace = "default"
                            }
                            source = "Secret"
                        }
                        identity = {
                            secretRef = {
                                key = "token"
                                name = "upbound-token"
                                namespace = "default"
                            }
                            source = "Secret"
                            $type = "UpboundTokens"
                        }
                    }
                }
            ]
            compositionPath: "apis/environments/composition.yaml"
            xrPath: "examples/environment/example-no-cloudprovider-resources.yaml"
            xrdPath: "apis/environments/definition.yaml"
            context: {}
            extraResources: [
            ]
            observedResources = [
                kubernetesm.Object{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "observedCtpKubeconfig"
                        }
                        name = "observed-bootstrap-ctp-kubeconfig"

                        namespace = "default"
                    }
                    spec = {
                        forProvider = {
                            manifest = {}
                        }
                        managementPolicies = [
                            "Observe"
                        ]
                    }
                    status = {
                        atProvider = {
                            manifest = {
                                data = {
                                    kubeconfig = "YXBpVmVyc2lvbjogdjEKY2x1c3RlcnM6Ci0gY2x1c3RlcjoKICAgIGluc2VjdXJlLXNraXAtdGxzLXZlcmlmeTogdHJ1ZQogICAgc2VydmVyOiBodHRwczovL3VwYm91bmQtYXdzLXVzLWVhc3QtMS5zcGFjZS5teGUudXBib3VuZC5pby9hcGlzL3NwYWNlcy51cGJvdW5kLmlvL3YxYmV0YTEvbmFtZXNwYWNlcy9zb2x1dGlvbnMtbm9uLXByb2QvY29udHJvbHBsYW5lcy9ib290c3RyYXAvazhzCiAgbmFtZTogdXBib3VuZApjb250ZXh0czoKLSBjb250ZXh0OgogICAgY2x1c3RlcjogdXBib3VuZAogICAgZXh0ZW5zaW9uczoKICAgIC0gZXh0ZW5zaW9uOgogICAgICAgIGFwaVZlcnNpb246IHVwYm91bmQuaW8vdjFhbHBoYTEKICAgICAgICBraW5kOiBTcGFjZUV4dGVuc2lvbgogICAgICAgIHNwZWM6CiAgICAgICAgICBjbG91ZDoKICAgICAgICAgICAgb3JnYW5pemF0aW9uOiB1cGJvdW5kCiAgICAgIG5hbWU6IHNwYWNlcy51cGJvdW5kLmlvL3NwYWNlCiAgICBuYW1lc3BhY2U6IGRlZmF1bHQKICAgIHVzZXI6IHVwYm91bmQKICBuYW1lOiB1cGJvdW5kCmN1cnJlbnQtY29udGV4dDogdXBib3VuZApraW5kOiBDb25maWcKcHJlZmVyZW5jZXM6IHt9CnVzZXJzOgotIG5hbWU6IHVwYm91bmQKICB1c2VyOgogICAgZXhlYzoKICAgICAgYXBpVmVyc2lvbjogY2xpZW50LmF1dGhlbnRpY2F0aW9uLms4cy5pby92MQogICAgICBhcmdzOgogICAgICAtIG9yZ2FuaXphdGlvbgogICAgICAtIHRva2VuCiAgICAgIGNvbW1hbmQ6IHVwCiAgICAgIGVudjoKICAgICAgLSBuYW1lOiBPUkdBTklaQVRJT04KICAgICAgICB2YWx1ZTogdXBib3VuZAogICAgICAtIG5hbWU6IFVQX1BST0ZJTEUKICAgICAgICB2YWx1ZTogZGVmYXVsdAogICAgICBpbnRlcmFjdGl2ZU1vZGU6IElmQXZhaWxhYmxlCiAgICAgIHByb3ZpZGVDbHVzdGVySW5mbzogZmFsc2UK"
                                }
                            }
                        }
                    }
                }
                # Team and robot objects
                {
                    apiVersion = "m.upbound.io/v1alpha1"
                    kind = "ProviderConfig"
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "providerConfigUpbound"
                        }
                        generateName = "example-"
                        labels = {
                            "crossplane.io/composite" = "example"
                        }
                        name = "solutions-non-prod-example"

                        namespace = "default"
                    }
                    spec = {
                        credentials = {
                            secretRef = {
                                key = "token"
                                name = "upbound-token"
                                namespace = "default"
                            }
                            source = "Secret"
                        }
                        organization = "upbound"
                    }
                }
                {
                    apiVersion = "iam.m.upbound.io/v1alpha1"
                    kind = "Team"
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "envTeam"
                        }
                        generateName = "example-"
                        labels = {
                            "crossplane.io/composite" = "example"
                        }
                        name = "solutions-non-prod-example-team"

                        namespace = "default"
                    }
                    spec = {
                        forProvider = {
                            name = "solutions-non-prod-example"
                            organizationName = "upbound"
                        }
                        managementPolicies = ["*"]
                        providerConfigRef = {
                            kind = "ProviderConfig"
                            name = "solutions-non-prod-example"
                        }
                    }
                }
                {
                    apiVersion = "iam.m.upbound.io/v1alpha1"
                    kind = "Token"
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "envRobotToken"
                        }
                        generateName = "example-"
                        labels = {
                            "crossplane.io/composite" = "example"
                        }
                        name = "solutions-non-prod-example-robot-token"

                        namespace = "default"
                    }
                    spec = {
                        forProvider = {
                            name = "solutions-non-prod-example"
                            owner = {
                                idRef = {
                                    name = "solutions-non-prod-example-robot"

                                    namespace = "default"
                                }
                                $type = "robots"
                            }
                        }
                        managementPolicies = ["*"]
                        providerConfigRef = {
                            kind = "ProviderConfig"
                            name = "solutions-non-prod-example"
                        }
                        writeConnectionSecretToRef = {
                            name = "solutions-non-prod-example-robot-token"
                        }
                    }
                }
                {
                    apiVersion = "iam.m.upbound.io/v1alpha1"
                    kind = "Robot"
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "envRobot"
                        }
                        generateName = "example-"
                        labels = {
                            "crossplane.io/composite" = "example"
                        }
                        name = "solutions-non-prod-example-robot"

                        namespace = "default"
                    }
                    spec = {
                        forProvider = {
                            description = "Robot for solutions-non-prod-example"
                            name = "solutions-non-prod-example-bot"
                            owner = {
                                name = "upbound"

                                namespace = "default"
                            }
                        }
                        managementPolicies = ["*"]
                        providerConfigRef = {
                            kind = "ProviderConfig"
                            name = "solutions-non-prod-example"
                        }
                    }
                }
                {
                    apiVersion = "iam.m.upbound.io/v1alpha1"
                    kind = "RobotTeamMembership"
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "envRobotTeamMembership"
                        }
                        generateName = "example-"
                        labels = {
                            "crossplane.io/composite" = "example"
                        }
                        name = "solutions-non-prod-example-robot-team-membership"

                        namespace = "default"
                    }
                    spec = {
                        forProvider = {
                            robotIdRef = {
                                name = "solutions-non-prod-example-robot"

                                namespace = "default"
                            }
                            teamIdRef = {
                                name = "solutions-non-prod-example-team"

                                namespace = "default"
                            }
                        }
                        managementPolicies = ["*"]
                        providerConfigRef = {
                            kind = "ProviderConfig"
                            name = "solutions-non-prod-example"
                        }
                    }
                }
                kubernetesm.Object{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "robotTokenEnvCtpSecret"
                        }
                        generateName = "example-"
                        labels = {
                            "crossplane.io/composite" = "example"
                        }
                        name = "solutions-non-prod-example-rt-secret"

                        namespace = "default"
                    }
                    spec = {
                        forProvider = {
                            manifest = {
                                apiVersion = "v1"
                                kind = "Secret"
                                metadata = {
                                    namespace = "default"
                                }
                            }
                        }
                        managementPolicies = ["*"]
                        providerConfigRef = {
                            kind = "ProviderConfig"
                            name = "example-ctp"
                        }
                        references = [
                            {
                                patchesFrom = {
                                    apiVersion = "v1"
                                    fieldPath = "data.token"
                                    kind = "Secret"
                                    name = "solutions-non-prod-example-robot-token"
                                }
                                toFieldPath = "data.token"
                            }
                        ]
                        watch = False
                    }
                }
            ]
            timeoutSeconds = 60
            validate = False
        }
    }
]

items = _items
