#!/bin/sh

set -eu

ipk=${1:-}
[ -n "$ipk" ] || { echo "Usage: $0 PACKAGE.ipk" >&2; exit 2; }
[ -f "$ipk" ] || { echo "Package not found: $ipk" >&2; exit 1; }

work=$(mktemp -d "${TMPDIR:-/tmp}/kvas-compat-ipk-verify.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

tar -xzf "$ipk" -C "$work"
tar -xzf "$work/control.tar.gz" -C "$work"
tar -xzf "$work/data.tar.gz" -C "$work"

test "$(cat "$work/debian-binary")" = 2.0
grep -Eq '^Package: kvas$' "$work/control"
grep -Eq '^Version: 1.1.9_beta-10-353$' "$work/control"
test -x "$work/postinst"
test -f "$work/opt/apps/kvas/bin/kvas"
test -f "$work/opt/apps/kvas/bin/libs/vpn"
test -f "$work/opt/apps/kvas/bin/libs/vless"
test -f "$work/opt/apps/kvas/bin/libs/ndm"
test -f "$work/opt/apps/kvas/etc/ndm/ndm"
test -f "$work/opt/apps/kvas/bin/libs/hysteria"
test -f "$work/opt/apps/kvas/hysteria/etc/init.d/S99hysteria"
test -f "$work/opt/etc/init.d/S96kvas"
test -f "$work/opt/etc/ndm/fs.d/15-kvas-start.sh"
test -f "$work/opt/etc/ndm/netfilter.d/100-dns-local"
cmp -s "$work/opt/apps/kvas/etc/ndm/ndm" "$work/opt/apps/kvas/bin/libs/ndm"
grep -Fq '"${connected}" != '\''yes'\''' "$work/opt/apps/kvas/bin/libs/vpn"
grep -Fq 'XRAY_INIT=/opt/etc/init.d/S97xray' "$work/opt/apps/kvas/bin/libs/vless"
grep -Fq 'S97xray' "$work/opt/apps/kvas/bin/libs/vpn"
grep -Fq 'RULE_PRIORITY=99' "$work/opt/apps/kvas/etc/ndm/ndm"
! grep -Eq '^[^#]*kvas init' "$work/postinst"
! grep -Fq '/opt/etc/kvas.conf' "$work/postinst"

printf 'OK: %s\n' "$ipk"
