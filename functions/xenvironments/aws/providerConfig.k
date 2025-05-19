import models.io.upbound.aws.v1beta1 as awsv1beta1
import utils

schema AWSProviderConfigInput:
    awsCredsSecretRef?: awsv1beta1.AwsUpboundIoV1beta1ProviderConfigSpecCredentialsSecretRef
    awsRoleArn?: str
    envName: str

getProviderConfig = lambda awsParams: AWSProviderConfigInput -> [any] {[
    awsv1beta1.ProviderConfig{
        metadata = utils._metadata("awsProviderConfig") | {
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
