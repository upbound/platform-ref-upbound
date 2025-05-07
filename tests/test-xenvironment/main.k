import models.io.crossplane.kubernetes.v1alpha1 as kubernetesv1alpha1
import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
import models.io.upbound.aws.iam.v1beta1 as iamv1beta1
import models.io.upbound.aws.secretsmanager.v1beta1 as secretsmanagerv1beta1
import models.io.upbound.aws.v1beta1 as awsv1beta1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.sa.v1 as sav1


_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-xenvironment"
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
                kubernetesv1alpha2.Object{
                    kind = "Object"
                    metadata = {
                        name = "solutions-non-prod-example-secrets-read-access-key"
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            manifest = {
                                apiVersion = "v1"
                                kind = "Secret"
                                metadata = {
                                    name = "solutions-non-prod-example-secrets-read-access-key"
                                    namespace = "solutions-non-prod-example"
                                }
                            }
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "solutions-non-prod-example-group"
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
                ### AWS ###
                iamv1beta1.Role{
                    metadata = {
                        name = "upbound-solutions-non-prod-example-example-admin"
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                    assumeRolePolicy = r"""{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::12345678912:oidc-provider/proidc.upbound.io"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "proidc.upbound.io:sub": "mcp:upbound/example:provider:provider-aws",
                    "proidc.upbound.io:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}"""
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "solutions-non-prod-example"
                        }
                    }
                }
                iamv1beta1.RolePolicyAttachment{
                    metadata = {
                        name = "upbound-solutions-non-prod-example-example-admin"
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            policyArn = "arn:aws:iam::aws:policy/AdministratorAccess"
                            roleSelector = {
                                matchControllerRef = True
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
                iamv1beta1.Policy{
                    metadata: {
                        name: "upbound-solutions-non-prod-example-example-secrets-read"
                    }
                    spec: {
                        deletionPolicy: "Orphan"
                        managementPolicies: ["*"]
                        forProvider: {
                            policy: """{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:ListSecretVersionIds"
            ],
            "Resource": [
                "arn:aws:secretsmanager:us-east-1:12345678912:secret:upbound-solutions-non-prod-example-example-*"
            ]
        }
    ]
}"""
                        }
                        providerConfigRef: {
                            name: "solutions-non-prod-example"
                        }
                    }
                }
                iamv1beta1.UserPolicyAttachment{
                    metadata: {
                        name: "upbound-solutions-non-prod-example-example-secrets-read"
                    }
                    spec: {
                        deletionPolicy: "Orphan"
                        managementPolicies: ["*"]
                        forProvider: {
                            policyArnSelector: {
                              matchControllerRef: True
                            }
                            userSelector: {
                              matchControllerRef: True
                            }
                        }
                        providerConfigRef: {
                            name: "solutions-non-prod-example"
                        }
                    }
                }
                iamv1beta1.AccessKey{
                    metadata: {
                        name: "upbound-solutions-non-prod-example-example-secrets-read"
                    }
                    spec: {
                        deletionPolicy: "Orphan"
                        managementPolicies: ["*"]
                        forProvider: {
                            userSelector: {
                                matchControllerRef: True
                            }
                        }
                        providerConfigRef: {
                            name: "solutions-non-prod-example"
                        }
                        writeConnectionSecretToRef: {
                            name: "solutions-non-prod-example-secrets-read-access-key"
                            namespace: "default"
                        }
                    }
                }
                iamv1beta1.User{
                    metadata: {
                        name: "upbound-solutions-non-prod-example-example-secrets-read"
                    }
                    spec: {
                    deletionPolicy: "Orphan"
                        managementPolicies: ["*"]
                        forProvider: {}
                        providerConfigRef: {
                            name: "solutions-non-prod-example"
                        }
                    }
                }
                kubernetesv1alpha2.Object{
                    metadata = {
                        name = "example-ses"
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            manifest = {
                                apiVersion = "spaces.upbound.io/v1alpha1"
                                kind = "SharedExternalSecret"
                                metadata = {
                                    name = "example"
                                    namespace = "solutions-non-prod-example"
                                }
                                spec = {
                                    controlPlaneSelector = {
                                        names = [
                                            "example"
                                        ]
                                    }
                                    externalSecretSpec = {
                                        dataFrom = [
                                            {
                                                extract = {
                                                    conversionStrategy = "Default"
                                                    decodingStrategy = "None"
                                                    key = "upbound-solutions-non-prod-example-example-config"
                                                    metadataPolicy = "None"
                                                }
                                            }
                                        ]
                                        refreshInterval = "1m"
                                        secretStoreRef = {
                                            kind = "ClusterSecretStore"
                                            name = "example"
                                        }
                                        target = {
                                            creationPolicy = "Owner"
                                            deletionPolicy = "Retain"
                                            name = "example"
                                        }
                                    }
                                    namespaceSelector = {
                                        names = [
                                            "default"
                                        ]
                                    }
                                }
                            }
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "solutions-non-prod-example-group"
                        }
                        watch = False
                    }
                }
                kubernetesv1alpha2.Object{
                    metadata = {
                        name = "example-sss"
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            manifest = {
                                apiVersion = "spaces.upbound.io/v1alpha1"
                                kind = "SharedSecretStore"
                                metadata = {
                                    name = "example"
                                    namespace = "solutions-non-prod-example"
                                }
                                spec = {
                                    controlPlaneSelector = {
                                        names = [
                                            "example"
                                        ]
                                    }
                                    namespaceSelector = {
                                        names = [
                                            "default"
                                        ]
                                    }
                                    provider = {
                                        aws = {
                                            auth = {
                                                secretRef = {
                                                    accessKeyIDSecretRef = {
                                                        key = "username"
                                                        name = "solutions-non-prod-example-secrets-read-access-key"
                                                    }
                                                    secretAccessKeySecretRef = {
                                                        key = "password"
                                                        name = "solutions-non-prod-example-secrets-read-access-key"
                                                    }
                                                }
                                            }
                                            region = "us-east-1"
                                            service = "SecretsManager"
                                        }
                                    }
                                }
                            }
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "solutions-non-prod-example-group"
                        }
                        watch = False
                    }
                }
                awsv1beta1.ProviderConfig{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "solutions-non-prod-example"
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
                                key = "credentials"
                                name = "aws-creds-example"
                                namespace = "default"
                            }
                            source = "Secret"
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
                iamv1beta1.OpenIDConnectProvider{
                    metadata = {
                        name = "upbound-solutions-non-prod-example-example-oidc-provider"
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            clientIdList = [
                                "sts.amazonaws.com"
                            ]
                            url = "https://proidc.upbound.io"
                        }
                        managementPolicies = [
                            "*"
                        ]
                        providerConfigRef = {
                            name = "solutions-non-prod-example"
                        }
                    }
                }
                secretsmanagerv1beta1.Secret{
                    metadata = {
                        name = "upbound-solutions-non-prod-example-example-secretsmanager-secret"
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            name = "upbound-solutions-non-prod-example-example-config"
                            region = "us-east-1"
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
            xrPath: "examples/xenvironment/example.yaml"
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
                        labels = {
                            "crossplane.io/composite" = "example"
                        }
                        name = "solutions-non-prod-example <- that this test doesn't fail is a bug, leave it here to uncover when fixed"
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
