"""Argo CD cluster registration for the environment's control plane."""

import base64
import json

from .kubernetes import k8s_object
from .util import pc_ref


def argo_server_secret(*, access_token, org, group, ctp, provider_config_name, server_ca_data, space_host) -> list:
    """Register the environment's control plane as a cluster with Argo CD."""
    cluster = f"{group}-{ctp}"
    config = {
        "execProviderConfig": {
            "apiVersion": "client.authentication.k8s.io/v1",
            "command": "up",
            "args": ["org", "token"],
            "env": {"ORGANIZATION": org, "UP_TOKEN": access_token},
        },
        "tlsClientConfig": {"insecure": False},
    }
    # KCL dropped a key whose value was Undefined; the CA is absent when the bootstrap
    # kubeconfig carries none.
    if server_ca_data is not None:
        config["tlsClientConfig"]["caData"] = server_ca_data
    b64 = lambda s: base64.b64encode(s.encode()).decode()
    return [("ctp-argocd", k8s_object(f"{ctp}-ctp-argocd-secret", {
        "managementPolicies": ["*"],
        "forProvider": {"manifest": {
            "apiVersion": "v1",
            "kind": "Secret",
            "metadata": {
                "name": cluster,
                "namespace": "argocd",
                "labels": {"argocd.argoproj.io/secret-type": "cluster"},
            },
            "type": "Opaque",
            "data": {
                "name": b64(cluster),
                "server": b64(f"https://{space_host}/apis/spaces.upbound.io/v1beta1/namespaces/{group}/controlplanes/{ctp}/k8s"),
                "config": b64(json.dumps(config)),
            },
        }},
        "providerConfigRef": pc_ref(provider_config_name),
    }))]
