import models.io.crossplane.kubernetes.v1alpha1 as kubernetesv1alpha1
import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
import models.io.upbound.aws.iam.v1beta1 as iamv1beta1
import models.io.upbound.aws.v1beta1 as awsv1beta1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.sa.v1 as sav1
import json
import base64


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
                sav1.XSharedAWSSecret{
                    metadata = {
                        name = "example-shared-secret"
                    }
                    spec = {
                        parameters = {
                            deletionPolicy = "Orphan"
                            aws = {
                                accountId = "12345678912"
                                region = "us-east-1"
                                namePrefix = "upbound-solutions-non-prod-example-example"
                                providerConfigRef = {
                                    name = "solutions-non-prod-example"
                                }
                            }
                            upbound = {
                                group = "solutions-non-prod-example"
                                controlPlane = "example"
                                providerConfigRef = {
                                    name = "solutions-non-prod-example-group"
                                }
                            }
                        }
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

                kubernetesv1alpha2.Object{
                    metadata = {
                        name = "example-observed-access-token-observed"
                    }
                    spec = {
                        forProvider = {
                            manifest = {
                                apiVersion = "v1"
                                kind = "Secret"
                                metadata = {
                                    name = "upbound-token"
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
                    }
                }

                kubernetesv1alpha2.Object{
                    metadata = {
                        name = "example-ctp-argocd-secret"
                    }
                    spec = {
                        forProvider = {
                            manifest = {
                                apiVersion: "v1"
                                kind: "Secret"
                                metadata: {
                                    name: "solutions-non-prod-example-example"
                                    namespace: "argocd"
                                    labels: {
                                        "argocd.argoproj.io/secret-type": "cluster"
                                    }
                                }
                                type: "Opaque"
                                stringData: {
                                    name: "solutions-non-prod-example-example"
                                    server: "https://upbound-aws-us-east-1.space.mxe.upbound.io/apis/spaces.upbound.io/v1beta1/namespaces/solutions-non-prod-example/controlplanes/example/k8s"
                                    config: json.encode({
                                        execProviderConfig: {
                                            apiVersion: "client.authentication.k8s.io/v1"
                                            command: "up"
                                            args: [
                                                "org"
                                                "token"
                                            ]
                                            env: {
                                                "ORGANIZATION": "upbound"
                                                "UP_TOKEN": "uptest-token"
                                            }
                                        }
                                        tlsClientConfig: {
                                            insecure: False
                                            caData: "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJ6ekNDQVhTZ0F3SUJBZ0lSQUtuaU1IS1lkN01oQUJDbzMxRHI3cDh3Q2dZSUtvWkl6ajBFQXdJd056RUwKTUFrR0ExVUVCaE1DVlZNeEVEQU9CZ05WQkFvVEIzVndZbTkxYm1ReEZqQVVCZ05WQkFNVERWVndZbTkxYm1RcwpJRWx1WXk0d0hoY05NalV3TXpBeU1EQXpPVE0wV2hjTk1qWXdNekF5TURBek9UTTBXakEzTVFzd0NRWURWUVFHCkV3SlZVekVRTUE0R0ExVUVDaE1IZFhCaWIzVnVaREVXTUJRR0ExVUVBeE1OVlhCaWIzVnVaQ3dnU1c1akxqQloKTUJNR0J5cUdTTTQ5QWdFR0NDcUdTTTQ5QXdFSEEwSUFCTTUyUE5BWFNuQ0pHNzdWbmU2K01VVWllSW5SdmR4YQpOaDlqeW5NS3RMM2QrdWNTMTQ0R3ZLbFpiS3l1dXZzZDhrSkJyZWg3V1A3Sk9pcDFyRmU1T2d5allUQmZNQTRHCkExVWREd0VCL3dRRUF3SUJwakFkQmdOVkhTVUVGakFVQmdnckJnRUZCUWNEQVFZSUt3WUJCUVVIQXdJd0R3WUQKVlIwVEFRSC9CQVV3QXdFQi96QWRCZ05WSFE0RUZnUVUydmJKZTBVbzJjMmlsODdXOGhISWRUdHZVeWd3Q2dZSQpLb1pJemowRUF3SURTUUF3UmdJaEFLSDlLTWFHelVjcVo3NHR1aVI5VFd6S2tnakRMNWlTRWZmM0ZENktaZy9PCkFpRUFwVU8yMGZtRU9Ua0hsUHN2MTh2T1VVby8rRWJnSXo3M00waG5VQysySFJFPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="
                                        }
                                    })
                                }
                            }
                        }
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
            observedResources = [
                kubernetesv1alpha2.Object{
                    metadata = {
                        name = "example-observed-access-token-observed"
                        annotations: {
                            "crossplane.io/composition-resource-name": "observed-access-token"
                        }
                    }
                    spec = {
                        forProvider = {
                            manifest = {
                                apiVersion = "v1"
                                kind = "Secret"
                                metadata = {
                                    name = "upbound-token"
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
                    }
                    status = {
                        atProvider = {
                            manifest = {
                                data = {
                                    token = base64.encode("uptest-token")
                                }
                            }
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
                                    kubeconfig = "YXBpVmVyc2lvbjogdjEKY2x1c3RlcnM6Ci0gY2x1c3RlcjoKICAgIGNlcnRpZmljYXRlLWF1dGhvcml0eS1kYXRhOiBMUzB0TFMxQ1JVZEpUaUJEUlZKVVNVWkpRMEZVUlMwdExTMHRDazFKU1VKNmVrTkRRVmhUWjBGM1NVSkJaMGxTUVV0dWFVMUlTMWxrTjAxb1FVSkRiek14UkhJM2NEaDNRMmRaU1V0dldrbDZhakJGUVhkSmQwNTZSVXdLVFVGclIwRXhWVVZDYUUxRFZsWk5lRVZFUVU5Q1owNVdRa0Z2VkVJelZuZFpiVGt4WW0xUmVFWnFRVlZDWjA1V1FrRk5WRVJXVm5kWmJUa3hZbTFSY3dwSlJXeDFXWGswZDBob1kwNU5hbFYzVFhwQmVVMUVRWHBQVkUwd1YyaGpUazFxV1hkTmVrRjVUVVJCZWs5VVRUQlhha0V6VFZGemQwTlJXVVJXVVZGSENrVjNTbFpWZWtWUlRVRTBSMEV4VlVWRGFFMUlaRmhDYVdJelZuVmFSRVZYVFVKUlIwRXhWVVZCZUUxT1ZsaENhV0l6Vm5WYVEzZG5VMWMxYWt4cVFsb0tUVUpOUjBKNWNVZFRUVFE1UVdkRlIwTkRjVWRUVFRRNVFYZEZTRUV3U1VGQ1RUVXlVRTVCV0ZOdVEwcEhOemRXYm1VMkswMVZWV2xsU1c1U2RtUjRZUXBPYURscWVXNU5TM1JNTTJRcmRXTlRNVFEwUjNaTGJGcGlTM2wxZFhaelpEaHJTa0p5WldnM1YxQTNTazlwY0RGeVJtVTFUMmQ1YWxsVVFtWk5RVFJIQ2tFeFZXUkVkMFZDTDNkUlJVRjNTVUp3YWtGa1FtZE9Wa2hUVlVWR2FrRlZRbWRuY2tKblJVWkNVV05FUVZGWlNVdDNXVUpDVVZWSVFYZEpkMFIzV1VRS1ZsSXdWRUZSU0M5Q1FWVjNRWGRGUWk5NlFXUkNaMDVXU0ZFMFJVWm5VVlV5ZG1KS1pUQlZiekpqTW1sc09EZFhPR2hJU1dSVWRIWlZlV2QzUTJkWlNRcExiMXBKZW1vd1JVRjNTVVJUVVVGM1VtZEphRUZMU0RsTFRXRkhlbFZqY1ZvM05IUjFhVkk1VkZkNlMydG5ha1JNTldsVFJXWm1NMFpFTmt0YVp5OVBDa0ZwUlVGd1ZVOHlNR1p0UlU5VWEwaHNVSE4yTVRoMlQxVlZieThyUldKblNYbzNNMDB3YUc1VlF5c3lTRkpGUFFvdExTMHRMVVZPUkNCRFJWSlVTVVpKUTBGVVJTMHRMUzB0Q2c9PQogICAgc2VydmVyOiBodHRwczovL3VwYm91bmQtYXdzLXVzLWVhc3QtMS5zcGFjZS5teGUudXBib3VuZC5pby9hcGlzL3NwYWNlcy51cGJvdW5kLmlvL3YxYmV0YTEvbmFtZXNwYWNlcy9zb2x1dGlvbnMtbm9uLXByb2QvY29udHJvbHBsYW5lcy9ib290c3RyYXAvazhzCiAgbmFtZTogdXBib3VuZApjb250ZXh0czoKLSBjb250ZXh0OgogICAgY2x1c3RlcjogdXBib3VuZAogICAgZXh0ZW5zaW9uczoKICAgIC0gZXh0ZW5zaW9uOgogICAgICAgIGFwaVZlcnNpb246IHVwYm91bmQuaW8vdjFhbHBoYTEKICAgICAgICBraW5kOiBTcGFjZUV4dGVuc2lvbgogICAgICAgIHNwZWM6CiAgICAgICAgICBjbG91ZDoKICAgICAgICAgICAgb3JnYW5pemF0aW9uOiB1cGJvdW5kCiAgICAgIG5hbWU6IHNwYWNlcy51cGJvdW5kLmlvL3NwYWNlCiAgICBuYW1lc3BhY2U6IGRlZmF1bHQKICAgIHVzZXI6IHVwYm91bmQKICBuYW1lOiB1cGJvdW5kCmN1cnJlbnQtY29udGV4dDogdXBib3VuZApraW5kOiBDb25maWcKcHJlZmVyZW5jZXM6IHt9CnVzZXJzOgotIG5hbWU6IHVwYm91bmQKICB1c2VyOgogICAgZXhlYzoKICAgICAgYXBpVmVyc2lvbjogY2xpZW50LmF1dGhlbnRpY2F0aW9uLms4cy5pby92MQogICAgICBhcmdzOgogICAgICAtIG9yZ2FuaXphdGlvbgogICAgICAtIHRva2VuCiAgICAgIGNvbW1hbmQ6IHVwCiAgICAgIGVudjoKICAgICAgLSBuYW1lOiBPUkdBTklaQVRJT04KICAgICAgICB2YWx1ZTogdXBib3VuZAogICAgICAtIG5hbWU6IFVQX1BST0ZJTEUKICAgICAgICB2YWx1ZTogZGVmYXVsdAogICAgICBpbnRlcmFjdGl2ZU1vZGU6IElmQXZhaWxhYmxlCiAgICAgIHByb3ZpZGVDbHVzdGVySW5mbzogZmFsc2UK"
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
