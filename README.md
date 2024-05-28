# platform-ref-upbound

This configuration shows how to bootstrap a control plane that acts as the main control plane to perform various actions not yet officially supported by the Upbound API.
These actions include creating control planes in different Upbound-hosted spaces, shared providers based on label selectors, shared deployment runtime configs based on label selectors, and more.
Therefore, the APIs in this configuration are in `contrib.space.upbound.io` and are flagged as `alpha`.

## bootstrap

```
export API_TOKEN=<api-token>
export ORGANIZATION=upbound
export CONTROLPLANE=ctp-main
export GROUP=default
export SPACE=upbound-aws-us-east-1

./examples/init/init.sh
```

## Available APIs
This repository implements Compositions for Group, ControlPlane, SharedProvider and SharedDeploymentRuntimeConfig.
For more information, review the API documentation below:

### Groups
- not operational today

### ControlPlane
- Provision/Manage ControlPlane and ProviderConfigs for ControlPlanes in various Upbound-hosted spaces.

### SharedProvider
- Provision/Manage multiple Providers based on ControlPlane selectors and report the status of the ProviderRevisions.

### SharedDeploymentRuntimeConfig
- Provision/Manage DeploymentRuntimeConfig for use in Provider deployments.

# Overview

This provides a good overview of two deployed ControlPlanes combined with SharedDeploymentRuntimeConfig and SharedProvider.

```
kubectl get managed
NAME                                                                          KIND                      PROVIDERCONFIG                               SYNCED   READY   AGE
object.kubernetes.crossplane.io/ctp-dev-h99wr                                 Secret                    default                                      True     True    17m
object.kubernetes.crossplane.io/ctp-dev-l487f                                 ControlPlane              b411c978-14fe-4146-9caa-c045ad0bb22a-space   True     True   17m
object.kubernetes.crossplane.io/ctp-dev-qt64l                                 Secret                    default                                      True     True    17m
object.kubernetes.crossplane.io/ctp-qa-b8w4v                                  Secret                    default                                      True     True    17m
object.kubernetes.crossplane.io/ctp-qa-q8rrg                                  Secret                    default                                      True     True    17m
object.kubernetes.crossplane.io/ctp-qa-qp2f7                                  ControlPlane              af2d3a55-45b9-48ec-a9a4-99e4cd36873d-space   True     True   17m
object.kubernetes.crossplane.io/debug-bw5pw                                   DeploymentRuntimeConfig   b411c978-14fe-4146-9caa-c045ad0bb22a-ctp     True     True    51s
object.kubernetes.crossplane.io/debug-g458m                                   DeploymentRuntimeConfig   af2d3a55-45b9-48ec-a9a4-99e4cd36873d-ctp     True     True    51s
object.kubernetes.crossplane.io/upbound-upbound-aws-us-east-1-2cqbj-64835f1   ProviderRevision          b411c978-14fe-4146-9caa-c045ad0bb22a-ctp     True     True    43s
object.kubernetes.crossplane.io/upbound-upbound-aws-us-east-1-8drr4           Provider                  b411c978-14fe-4146-9caa-c045ad0bb22a-ctp     True     True    45s
object.kubernetes.crossplane.io/upbound-upbound-aws-us-east-1-8sgn2           Provider                  af2d3a55-45b9-48ec-a9a4-99e4cd36873d-ctp     True     True    44s
object.kubernetes.crossplane.io/upbound-upbound-aws-us-east-1-h8brn           Provider                  af2d3a55-45b9-48ec-a9a4-99e4cd36873d-ctp     True     True    44s
object.kubernetes.crossplane.io/upbound-upbound-aws-us-east-1-rkv8q           Provider                  b411c978-14fe-4146-9caa-c045ad0bb22a-ctp     True     True    45s
object.kubernetes.crossplane.io/upbound-upbound-aws-us-east-1-sbnww           Provider                  b411c978-14fe-4146-9caa-c045ad0bb22a-ctp     True     True    44s
object.kubernetes.crossplane.io/upbound-upbound-aws-us-east-1-vlnrn           Provider                  af2d3a55-45b9-48ec-a9a4-99e4cd36873d-ctp     True     True    45s

NAME                                                                                    KIND   PROVIDERCONFIG                             SYNCED   READY   AGE
observedobjectcollection.kubernetes.crossplane.io/upbound-upbound-aws-us-east-1-2cqbj          b411c978-14fe-4146-9caa-c045ad0bb22a-ctp   True     True    45s
observedobjectcollection.kubernetes.crossplane.io/upbound-upbound-aws-us-east-1-45q88          b411c978-14fe-4146-9caa-c045ad0bb22a-ctp   True     True    45s
observedobjectcollection.kubernetes.crossplane.io/upbound-upbound-aws-us-east-1-64wlh          af2d3a55-45b9-48ec-a9a4-99e4cd36873d-ctp   True     True    44s
observedobjectcollection.kubernetes.crossplane.io/upbound-upbound-aws-us-east-1-797pd          af2d3a55-45b9-48ec-a9a4-99e4cd36873d-ctp   True     True    45s
observedobjectcollection.kubernetes.crossplane.io/upbound-upbound-aws-us-east-1-gfsdn          b411c978-14fe-4146-9caa-c045ad0bb22a-ctp   True     True    45s
observedobjectcollection.kubernetes.crossplane.io/upbound-upbound-aws-us-east-1-xbqmt          af2d3a55-45b9-48ec-a9a4-99e4cd36873d-ctp   True     True    46s
```