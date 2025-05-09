import models.io.upbound.aws.v1beta1 as awsv1beta1

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

schema AWSProviderConfigInput:
    awsCredsSecretRef?: awsv1beta1.AwsUpboundIoV1beta1ProviderConfigSpecCredentialsSecretRef
    awsRoleArn?: str
    envName: str

getProviderConfig = lambda awsParams: AWSProviderConfigInput -> [any] {[
    awsv1beta1.ProviderConfig{
        metadata = _metadata("awsProviderConfig") | {
            name = awsParams.envName
            annotations = {
              "krm.kcl.dev/ready" = "True"
            }
        }
        spec = {
            if awsParams.awsRoleArn:
                credentials = {
                    source = "Upbound"
                    upbound = {
                        webIdentity = {
                            roleARN = awsParams.awsRoleArn
                        }
                    }
                }
            else:
                credentials = {
                    source = "Secret"
                    secretRef = awsParams.awsCredsSecretRef
                }
        }
}]}
