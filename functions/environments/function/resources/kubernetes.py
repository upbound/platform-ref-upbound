"""provider-kubernetes Objects, kubeconfigs and ProviderConfigs for Upbound Spaces."""

import base64

import yaml
from models.io.crossplane.m.kubernetes.object import v1alpha1 as objectv1alpha1
from models.io.crossplane.m.kubernetes.providerconfig import v1alpha1 as k8spcv1alpha1
from models.io.crossplane.protection.usage import v1beta1 as usagev1beta1

from ..common.kcl_parity import OBJECT_FOR_PROVIDER_DEFAULTS, OBJECT_SPEC_DEFAULTS
from .util import pc_ref

OBJECT_API = "kubernetes.m.crossplane.io/v1alpha1"


def object_spec(spec: dict) -> dict:
    """An Object spec with the provider-kubernetes defaults KCL materialised."""
    spec = {**OBJECT_SPEC_DEFAULTS, **spec}
    spec["forProvider"] = {**OBJECT_FOR_PROVIDER_DEFAULTS, **spec["forProvider"]}
    return spec


def k8s_object(name: str | None, spec: dict, annotations: dict | None = None) -> objectv1alpha1.Object:
    metadata = {}
    if name is not None:
        metadata["name"] = name
    if annotations:
        metadata["annotations"] = annotations
    return objectv1alpha1.Object.model_validate({"metadata": metadata, "spec": object_spec(spec)})


def upbound_kubeconfig(space_host: str, org: str, group: str, ctp: str) -> dict:
    """A kubeconfig for the Space (ctp == "") or for one control plane in it.

    Authenticates by running `up organization token`, which provider-kubernetes supplies
    with the Upbound token through the ProviderConfig's UpboundTokens identity.
    """
    server = (
        f"https://{space_host}"
        if ctp == ""
        else f"https://{space_host}/apis/spaces.upbound.io/v1beta1/namespaces/{group}/controlplanes/{ctp}/k8s"
    )
    return {
        "apiVersion": "v1",
        "clusters": [{"cluster": {"insecure-skip-tls-verify": True, "server": server}, "name": "upbound"}],
        "contexts": [{
            "context": {
                "cluster": "upbound",
                "extensions": [{
                    "extension": {
                        "apiVersion": "upbound.io/v1alpha1",
                        "kind": "SpaceExtension",
                        "spec": {"cloud": {"organization": org}},
                    },
                    "name": "spaces.upbound.io/space",
                }],
                "namespace": group if ctp == "" else "default",
                "user": "upbound",
            },
            "name": "upbound",
        }],
        "current-context": "upbound",
        "kind": "Config",
        "preferences": {},
        "users": [{
            "name": "upbound",
            "user": {"exec": {
                "apiVersion": "client.authentication.k8s.io/v1",
                "args": ["organization", "token"],
                "command": "up",
                "env": [{"name": "ORGANIZATION", "value": org}, {"name": "UP_PROFILE", "value": "default"}],
                "interactiveMode": "IfAvailable",
                "provideClusterInfo": False,
            }},
        }],
    }


def upbound_provider_config(*, space_host, org, provider_config_name, secret_namespace, token_ref,
                            group=None, ctp=None, prefix=None) -> list:
    """A provider-kubernetes ProviderConfig for the Space, a group, or a control plane.

    Three resources: the kubeconfig Secret (applied through an Object), the ProviderConfig
    that reads it, and a Usage that keeps the Secret until the ProviderConfig is gone.
    """
    config_name = f"{ctp}-ctp" if ctp else (f"{group}-group" if group else f"{prefix}-space")
    scope = "envCtp" if ctp else ("envGroup" if group else "space")
    secret_name = f"{config_name}-kubeconfig"
    kubeconfig = yaml.safe_dump(upbound_kubeconfig(space_host, org, group or "default", ctp or ""), sort_keys=False)
    return [
        (f"{scope}Kubeconfig", k8s_object(secret_name, {
            # The API default, set explicitly: KCL materialised it.
            "managementPolicies": ["*"],
            "forProvider": {"manifest": {
                "apiVersion": "v1",
                "kind": "Secret",
                "metadata": {"name": secret_name, "namespace": secret_namespace},
                # base64 `data`, not `stringData`: provider-kubernetes records ownership of the
                # fields it writes, and stringData is never stored, so the next observe fails.
                "data": {"kubeconfig": base64.b64encode(kubeconfig.encode()).decode()},
            }},
            "providerConfigRef": pc_ref(provider_config_name),
        })),
        # Keyed by name: see the resources package docstring.
        (config_name, k8spcv1alpha1.ProviderConfig.model_validate({
            "metadata": {"name": config_name},
            "spec": {
                "credentials": {
                    "source": "Secret",
                    "secretRef": {"name": secret_name, "namespace": secret_namespace, "key": "kubeconfig"},
                },
                "identity": {
                    "type": "UpboundTokens",
                    "source": "Secret",
                    "secretRef": token_ref,
                },
            },
        })),
        (f"{scope}Usage", usagev1beta1.Usage.model_validate({
            "metadata": {"name": secret_name},
            "spec": {
                "replayDeletion": True,
                "of": {"apiVersion": OBJECT_API, "kind": "Object", "resourceRef": {"name": secret_name}},
                "by": {"apiVersion": OBJECT_API, "kind": "ProviderConfig", "resourceRef": {"name": config_name}},
            },
        })),
    ]


def observe_secret(*, ctp, name, namespace, provider_config_name, resource_name) -> list:
    """An observe-only Object that reads a Secret off the bootstrap control plane."""
    return [(resource_name, k8s_object(f"{ctp}-{resource_name}-observed", {
        "managementPolicies": ["Observe"],
        "forProvider": {"manifest": {
            "apiVersion": "v1", "kind": "Secret", "metadata": {"name": name, "namespace": namespace},
        }},
        "providerConfigRef": pc_ref(provider_config_name),
    }))]
