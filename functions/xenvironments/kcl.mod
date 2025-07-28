[package]
name = "compose-environment"
version = "0.0.1"

[dependencies]
models = { path = "./model" }
spaces = { oci = "oci://xpkg.upbound.io/upbound/kcl-modules_spaces", tag = "1.12.0", package = "kcl-modules_spaces", version = "1.12.0" }
