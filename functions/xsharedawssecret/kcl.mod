[package]
name = "xsharedawssecret"
version = "0.0.1"

[dependencies]
models = { path = "./model" }
spaces = { oci = "oci://xpkg.upbound.io/upbound/kcl-modules_spaces", tag = "1.12.0", package = "kcl-modules_spaces", version = "1.12.0" }
kube = { oci = "oci://xpkg.upbound.io/upbound/kcl-modules_kube", tag = "1.31.2", package = "kcl-modules_kube", version = "1.31.2" }
