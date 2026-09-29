"""Output the KCL implementation produced without the functions asking for it.

These functions replaced KCL ones and keep their rendered output identical. KCL's typed
models materialised every schema default into their output, so a few provider defaults
appear in the desired state although no function set them. They change nothing on a cluster;
they are kept so the rendered desired state - what the composition tests assert - is unchanged.
"""

# provider-kubernetes Object defaults, emitted on every Object.
OBJECT_FOR_PROVIDER_DEFAULTS = {"deletionPropagationPolicy": "Background"}
OBJECT_SPEC_DEFAULTS = {"watch": False}
