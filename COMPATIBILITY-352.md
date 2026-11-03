# Compatibility baseline: `1.1.9_beta-10-352`

## Comparison

The published `kvas_1.1.9_beta-10-352_all.ipk` was extracted locally and
compared with the imported upstream `main` source.

- Published package app tree: 65 files.
- Current upstream `main` app tree: 53 files.
- The published package contains 11 files absent from current `main`, including
  backup/restore helpers, the Hysteria helper tree, and the runtime
  `bin/libs/ndm` copy.
- Shared files are not byte-identical; `vpn`, `vless`, `ndm`, setup/UI files,
  and several helpers differ.
- Published `352` has `RULE_PRIORITY=99` in `etc/ndm/ndm`.
- Current upstream `main` has `RULE_PRIORITY=1778` in that file.
- Published `352` still checks VPN readiness through the `state` field and
  fabricates the `/24` helper route for an interface without `ADDR_MAN`.
- Published `352` still references `S24xray`; the installed router has a local
  S97xray compatibility modification that is not part of the published IPK.

## Baseline decision

The compatibility branch uses the published `352` app tree as its source
baseline. This preserves files already present in the installed release and
avoids silently replacing the router's feature set with the smaller current
upstream tree. The `main` branch remains available as a reference for later
forward-porting.

Only the reviewed VLESS/KVAS safety changes will be applied on top of this
baseline. Router-specific S97xray integration remains an explicit compatibility
patch and is not copied into the upstream reference branch.
