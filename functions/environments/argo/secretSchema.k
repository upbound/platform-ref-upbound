schema ArgoServerSecret:
    r"""
    ArgoServerSecret represents an Input for an Argo Server Secret.

    Attributes
    ----------
    spaceHost : str, required
        The Upbound Spaces host (e.g. spaces.upbound.io)
    org : str, required
        The Upbound organization name
    group : str, required
        The group name for group-level access
    ctp : str, required
        The control plane name for control plane-level access
    providerConfigName : str, required
        The Name of the provider config to reference
    accessToken : str, required
        The AccessToken (PersonalAccessToken or RobotToken)
    serverCaData : str, required
        The ServerCaData as base64 encoded string
    """

    spaceHost: str
    org: str
    group: str
    ctp: str
    providerConfigName: str
    accessToken: str
    serverCaData: str
