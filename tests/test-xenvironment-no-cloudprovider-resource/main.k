import models.io.crossplane.kubernetes.v1alpha1 as kubernetesv1alpha1
import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.sa.v1 as sav1


_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-xenvironment-no-cloudprovider-resource"
        spec = {
            assertResources: [
                kubernetesv1alpha2.Object{
                    metadata: {
                        name: "example-ctp-kubeconfig"
                    }
                    spec: {
                        deletionPolicy: "Delete"
                        managementPolicies: ["*"]
                        forProvider: {
                            manifest: {
                                apiVersion: "v1"
                                kind: "Secret"
                                metadata: {
                                    name: "example-ctp-kubeconfig"
                                    namespace: "default"
                                }
                                stringData: {
                                    kubeconfig: "{'apiVersion': 'v1', 'clusters': [{'cluster': {'insecure-skip-tls-verify': True, 'server': 'https://upbound-aws-us-east-1.space.mxe.upbound.io/apis/spaces.upbound.io/v1beta1/namespaces/solutions-non-prod-example/controlplanes/example/k8s'}, 'name': 'upbound'}], 'contexts': [{'context': {'cluster': 'upbound', 'extensions': [{'extension': {'apiVersion': 'upbound.io/v1alpha1', 'kind': 'SpaceExtension', 'spec': {'cloud': {'organization': 'upbound'}}}, 'name': 'spaces.upbound.io/space'}], 'namespace': 'default', 'user': 'upbound'}, 'name': 'upbound'}], 'current-context': 'upbound', 'kind': 'Config', 'preferences': {}, 'users': [{'name': 'upbound', 'user': {'exec': {'apiVersion': 'client.authentication.k8s.io/v1', 'args': [organization, token], 'command': 'up', 'env': [{'name': 'ORGANIZATION', 'value': 'upbound'}, {'name': 'UP_PROFILE', 'value': 'default'}], 'interactiveMode': 'IfAvailable', 'provideClusterInfo': False}}}]}"
                                }
                            }
                        }
                        providerConfigRef: {
                            name: "bootstrap-ctp"
                        }
                        watch: False
                    }
                }
                kubernetesv1alpha2.Object{
                    metadata: {
                        name: "example-ctp"
                    }
                    spec: {
                        readiness: {
                            policy: "DeriveFromObject"
                        }
                        deletionPolicy: "Orphan"
                        managementPolicies: ["*"]
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
                kubernetesv1alpha2.Object{
                    metadata = {
                        name = "solutions-non-prod-example-group-kubeconfig"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {
                            manifest = {
                                apiVersion = "v1"
                                kind = "Secret"
                                metadata = {
                                    name = "solutions-non-prod-example-group-kubeconfig"
                                    namespace = "default"
                                }
                                stringData = {
                                    kubeconfig = "{'apiVersion': 'v1', 'clusters': [{'cluster': {'insecure-skip-tls-verify': True, 'server': 'https://upbound-aws-us-east-1.space.mxe.upbound.io'}, 'name': 'upbound'}], 'contexts': [{'context': {'cluster': 'upbound', 'extensions': [{'extension': {'apiVersion': 'upbound.io/v1alpha1', 'kind': 'SpaceExtension', 'spec': {'cloud': {'organization': 'upbound'}}}, 'name': 'spaces.upbound.io/space'}], 'namespace': 'solutions-non-prod-example', 'user': 'upbound'}, 'name': 'upbound'}], 'current-context': 'upbound', 'kind': 'Config', 'preferences': {}, 'users': [{'name': 'upbound', 'user': {'exec': {'apiVersion': 'client.authentication.k8s.io/v1', 'args': [organization, token], 'command': 'up', 'env': [{'name': 'ORGANIZATION', 'value': 'upbound'}, {'name': 'UP_PROFILE', 'value': 'default'}], 'interactiveMode': 'IfAvailable', 'provideClusterInfo': False}}}]}"
                                }
                            }
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "bootstrap-ctp"
                        }
                        watch = False
                    }
                }
                kubernetesv1alpha1.ProviderConfig{
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
               kubernetesv1alpha1.ProviderConfig{
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
                    apiVersion = "apiextensions.crossplane.io/v1alpha1"
                    kind = "Usage"
                    metadata = {
                        name = "example-space-kubeconfig"
                    }
                    spec = {
                        replayDeletion = True
                        of = {
                            apiVersion = "kubernetes.crossplane.io/v1alpha2"
                            kind = "Object"
                            resourceRef = {
                                name = "example-space-kubeconfig"
                            }
                        }
                        by = {
                            apiVersion = "kubernetes.crossplane.io/v1alpha1"
                            kind = "ProviderConfig"
                            resourceRef = {
                                name = "example-space"
                            }
                        }
                    }
                }
                {
                    apiVersion = "apiextensions.crossplane.io/v1alpha1"
                    kind = "Usage"
                    metadata = {
                        name = "solutions-non-prod-example-group-kubeconfig"
                    }
                    spec = {
                        replayDeletion = True
                        of = {
                            apiVersion = "kubernetes.crossplane.io/v1alpha2"
                            kind = "Object"
                            resourceRef = {
                                name = "solutions-non-prod-example-group-kubeconfig"
                            }
                        }
                        by = {
                            apiVersion = "kubernetes.crossplane.io/v1alpha1"
                            kind = "ProviderConfig"
                            resourceRef = {
                                name = "solutions-non-prod-example-group"
                            }
                        }
                    }
                }
                {
                    apiVersion = "apiextensions.crossplane.io/v1alpha1"
                    kind = "Usage"
                    metadata = {
                        name = "example-ctp-kubeconfig"
                    }
                    spec = {
                        replayDeletion = True
                        of = {
                            apiVersion = "kubernetes.crossplane.io/v1alpha2"
                            kind = "Object"
                            resourceRef = {
                                name = "example-ctp-kubeconfig"
                            }
                        }
                        by = {
                            apiVersion = "kubernetes.crossplane.io/v1alpha1"
                            kind = "ProviderConfig"
                            resourceRef = {
                                name = "example-ctp"
                            }
                        }
                    }
                }
                kubernetesv1alpha2.Object{
                    metadata = {
                        name = "example-space-kubeconfig"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {
                            manifest = {
                                apiVersion = "v1"
                                kind = "Secret"
                                metadata = {
                                    name = "example-space-kubeconfig"
                                    namespace = "default"
                                }
                                stringData = {
                                    kubeconfig = "{'apiVersion': 'v1', 'clusters': [{'cluster': {'insecure-skip-tls-verify': True, 'server': 'https://upbound-aws-us-east-1.space.mxe.upbound.io'}, 'name': 'upbound'}], 'contexts': [{'context': {'cluster': 'upbound', 'extensions': [{'extension': {'apiVersion': 'upbound.io/v1alpha1', 'kind': 'SpaceExtension', 'spec': {'cloud': {'organization': 'upbound'}}}, 'name': 'spaces.upbound.io/space'}], 'namespace': 'default', 'user': 'upbound'}, 'name': 'upbound'}], 'current-context': 'upbound', 'kind': 'Config', 'preferences': {}, 'users': [{'name': 'upbound', 'user': {'exec': {'apiVersion': 'client.authentication.k8s.io/v1', 'args': [organization, token], 'command': 'up', 'env': [{'name': 'ORGANIZATION', 'value': 'upbound'}, {'name': 'UP_PROFILE', 'value': 'default'}], 'interactiveMode': 'IfAvailable', 'provideClusterInfo': False}}}]}"
                                }
                            }
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "bootstrap-ctp"
                        }
                        watch = False
                    }
                }

                kubernetesv1alpha1.ProviderConfig{
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
            compositionPath: "apis/xenvironments/composition.yaml"
            xrPath: "examples/xenvironment/example-no-cloudprovider-resources.yaml"
            xrdPath: "apis/xenvironments/definition.yaml"
            context: []
            extraResources: [
                sav1.XEnvironment{
                    metadata = {
                        name = "example"
                    }
                    spec = {}
                    status = {
                        upbound = {
                            bootstrapCtp = "foo"
                            bootstrapGroup = "bar"
                            org = "upbound"
                            spaceHost = "foo"
                        }
                    }
                }
            ]
            observedResources = [
                sav1.XEnvironment{
                    metadata = {
                        name = "example"
                    }
                    spec = {}
                    status = {
                        upbound = {
                            bootstrapCtp = "foo"
                            bootstrapGroup = "bar"
                            org = "upbound"
                            spaceHost = "foo"
                        }
                    }
                }
                kubernetesv1alpha2.Object{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "observedCtpKubeconfig"
                        }
                        name = "observed-bootstrap-ctp-kubeconfig"
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
                    apiVersion = "upbound.io/v1alpha1"
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
                    apiVersion = "iam.upbound.io/v1alpha1"
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
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {
                            name = "solutions-non-prod-example"
                            organizationName = "upbound"
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "solutions-non-prod-example"
                        }
                    }
                }
                {
                    apiVersion = "iam.upbound.io/v1alpha1"
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
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {
                            name = "solutions-non-prod-example"
                            owner = {
                                idRef = {
                                    name = "solutions-non-prod-example-robot"
                                }
                                $type = "robots"
                            }
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "solutions-non-prod-example"
                        }
                        writeConnectionSecretToRef = {
                            name = "solutions-non-prod-example-robot-token"
                            namespace = "default"
                        }
                    }
                }
                {
                    apiVersion = "iam.upbound.io/v1alpha1"
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
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {
                            description = "Robot for solutions-non-prod-example"
                            name = "solutions-non-prod-example-bot"
                            owner = {
                                name = "upbound"
                            }
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "solutions-non-prod-example"
                        }
                    }
                }
                {
                    apiVersion = "iam.upbound.io/v1alpha1"
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
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {
                            robotIdRef = {
                                name = "solutions-non-prod-example-robot"
                            }
                            teamIdRef = {
                                name = "solutions-non-prod-example-team"
                            }
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "solutions-non-prod-example"
                        }
                    }
                }
                kubernetesv1alpha2.Object{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "robotTokenEnvCtpSecret"
                        }
                        generateName = "example-"
                        labels = {
                            "crossplane.io/composite" = "example"
                        }
                        name = "solutions-non-prod-example-rt-secret"
                    }
                    spec = {
                        deletionPolicy = "Delete"
                        forProvider = {
                            manifest = {
                                apiVersion = "v1"
                                kind = "Secret"
                                metadata = {
                                    namespace = "default"
                                }
                            }
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "example-ctp"
                        }
                        references = [
                            {
                                patchesFrom = {
                                    apiVersion = "v1"
                                    fieldPath = "data.token"
                                    kind = "Secret"
                                    name = "solutions-non-prod-example-robot-token"
                                    namespace = "default"
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
