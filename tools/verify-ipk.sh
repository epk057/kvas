#!/bin/sh

set -eu

ipk=${1:-}
[ -n "$ipk" ] || { echo "Usage: $0 PACKAGE.ipk" >&2; exit 2; }
[ -f "$ipk" ] || { echo "Package not found: $ipk" >&2; exit 1; }

work=$(mktemp -d "${TMPDIR:-/tmp}/kvas-ipk-verify.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

tar -xzf "$ipk" -C "$work"
test -f "$work/debian-binary"
test -f "$work/control.tar.gz"
test -f "$work/data.tar.gz"

tar -xzf "$work/control.tar.gz" -C "$work"
tar -xzf "$work/data.tar.gz" -C "$work"

test "$(cat "$work/debian-binary")" = 2.0
grep -Eq '^Package: kvas$' "$work/control"
grep -Eq '^Architecture: all$' "$work/control"
test -x "$work/postinst"
! grep -Fq '\$(PKG_VERSION)' "$work/postinst"
! grep -Fq '\$(PKG_RELEASE)' "$work/postinst"
test -f "$work/opt/apps/kvas/bin/kvas"
test -f "$work/opt/apps/kvas/bin/libs/vpn"
test -f "$work/opt/apps/kvas/etc/ndm/ndm"
test -f "$work/opt/etc/init.d/S96kvas"
test -f "$work/opt/etc/ndm/fs.d/15-kvas-start.sh"
test -f "$work/opt/etc/ndm/netfilter.d/100-dns-local"

printf 'OK: %s\n' "$ipk"
