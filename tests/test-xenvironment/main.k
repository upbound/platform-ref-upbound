import models.io.crossplane.kubernetes.v1alpha1 as kubernetesv1alpha1
import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
import models.io.upbound.aws.iam.v1beta1 as iamv1beta1
import models.io.upbound.aws.secretsmanager.v1beta1 as secretsmanagerv1beta1
import models.io.upbound.aws.v1beta1 as awsv1beta1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.sa.v1 as sav1


_items = [
    metav1alpha1.CompositionTest{
        spec= {
            assertResources: [
                sav1.XEnvironment{
                    metadata.name: "example"
                    spec.parameters: {
                    }
                }
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
                                    kubeconfig: "{'apiVersion': 'v1', 'clusters': [{'cluster': {'insecure-skip-tls-verify': True, 'server': 'https://upbound-aws-us-east-1.space.mxe.upbound.io/apis/spaces.upbound.io/v1beta1/namespaces/solutions-non-prod-example/controlplanes/example/k8s'}, 'name': 'upbound'}], 'contexts': [{'context': {'cluster': 'upbound', 'extensions': [{'extension': {'apiVersion': 'upbound.io/v1alpha1', 'kind': 'SpaceExtension', 'spec': {'cloud': {'organization': 'upboundcare'}}}, 'name': 'spaces.upbound.io/space'}], 'namespace': 'default', 'user': 'upbound'}, 'name': 'upbound'}], 'current-context': 'upbound', 'kind': 'Config', 'preferences': {}, 'users': [{'name': 'upbound', 'user': {'exec': {'apiVersion': 'client.authentication.k8s.io/v1', 'args': [organization, token], 'command': 'up', 'env': [{'name': 'ORGANIZATION', 'value': 'upboundcare'}, {'name': 'UP_PROFILE', 'value': 'default'}], 'interactiveMode': 'IfAvailable', 'provideClusterInfo': False}}}]}"
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
                                    kubeconfig = "{'apiVersion': 'v1', 'clusters': [{'cluster': {'insecure-skip-tls-verify': True, 'server': 'https://upbound-aws-us-east-1.space.mxe.upbound.io'}, 'name': 'upbound'}], 'contexts': [{'context': {'cluster': 'upbound', 'extensions': [{'extension': {'apiVersion': 'upbound.io/v1alpha1', 'kind': 'SpaceExtension', 'spec': {'cloud': {'organization': 'upboundcare'}}}, 'name': 'spaces.upbound.io/space'}], 'namespace': 'solutions-non-prod-example-example', 'user': 'upbound'}, 'name': 'upbound'}], 'current-context': 'upbound', 'kind': 'Config', 'preferences': {}, 'users': [{'name': 'upbound', 'user': {'exec': {'apiVersion': 'client.authentication.k8s.io/v1', 'args': [organization, token], 'command': 'up', 'env': [{'name': 'ORGANIZATION', 'value': 'upboundcare'}, {'name': 'UP_PROFILE', 'value': 'default'}], 'interactiveMode': 'IfAvailable', 'provideClusterInfo': False}}}]}"
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
                                data = None
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
                                name = "solutions-non-prod-bootstrap-token"
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
                        name = "upboundcare-solutions-non-prod-example-example-admin"
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
                "Federated": "arn:aws:iam:::oidc-provider/proidc.upbound.io"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "proidc.upbound.io:sub": "mcp:upboundcare/solutions-non-prod-example:provider:provider-aws",
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
                        name = "upboundcare-solutions-non-prod-example-example-admin"
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
                        name: "upboundcare-solutions-non-prod-example-example-secrets-read"
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
                "arn:aws:secretsmanager:us-east-1:12345678912:secret:upboundcare-solutions-non-prod-example-example-*"
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
                        name: "upboundcare-solutions-non-prod-example-example-secrets-read"
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
                        name: "upboundcare-solutions-non-prod-example-example-secrets-read"
                    }
                    spec: {
                        deletionPolicy: "Delete"
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
                        name: "upboundcare-solutions-non-prod-example-example-secrets-read"
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
                        name = "solutions-non-prod-example-secrets-read-access-key-observed"
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            manifest = {
                                apiVersion = "v1"
                                kind = "Secret"
                                metadata = {
                                    name = "solutions-non-prod-example-secrets-read-access-key"
                                    namespace = "default"
                                }
                            }
                        }
                        managementPolicies = [
                            "Observe"
                        ]
                        providerConfigRef = {
                            name = "bootstrap-ctp"
                        }
                        watch = False
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
                                                    key = "upboundcare-solutions-non-prod-example-example-config"
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
                        ownerReferences = [
                            {
                                apiVersion = "sa.upbound.io/v1"
                                blockOwnerDeletion = True
                                controller = True
                                kind = "XEnvironment"
                                name = "example"
                                uid = ""
                            }
                        ]
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
                                name = "solutions-non-prod-bootstrap-token"
                                namespace = "default"
                            }
                            source = "Secret"
                            $type = "UpboundTokens"
                        }
                    }
                }
                iamv1beta1.OpenIDConnectProvider{
                    metadata = {
                        name = "upboundcare-solutions-non-prod-example-example-oidc-provider"
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
                        name = "upboundcare-solutions-non-prod-example-example-secretsmanager-secret"
                    }
                    spec = {
                        deletionPolicy = "Orphan"
                        forProvider = {
                            name = "upboundcare-solutions-non-prod-example-example-config"
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

            ]
            compositionPath: "apis/xenvironments/composition.yaml"
            xrPath: "examples/xenvironment/example.yaml"
            xrdPath: "apis/xenvironments/definition.yaml"
            context: []
            extraResources: []
            observedResources: []
            timeoutSeconds: 60
            validate: False
        }
    }
]
items = _items
