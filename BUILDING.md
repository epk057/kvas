# Local KVAS IPK build

The repository contains an upstream OpenWrt/Entware `Makefile` and a Jenkins
pipeline, but the pipeline is tied to the original Jenkins installation and
contains router-copy/test stages. For local, router-independent builds use the
scripts in `tools/`.

## Build

From the repository root:

```sh
./tools/build-ipk.sh
./tools/verify-ipk.sh dist/kvas_1.1.9_beta-10-25_all.ipk
```

The version and release default to `PKG_VERSION` and `PKG_RELEASE` in the
Makefile. Override them without editing source files:

```sh
./tools/build-ipk.sh --release 353
```

The output is an Entware-style gzip-wrapped IPK containing `debian-binary`,
`control.tar.gz`, and `data.tar.gz`. The package is `Architecture: all`; no
MIPS compiler is needed because KVAS consists of shell scripts and data files.

The builder mirrors `Package/kvas/install` from the Makefile. It does not copy
anything to a router, run `opkg`, restart services, or execute package hooks.
