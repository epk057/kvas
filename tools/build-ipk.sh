#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MAKEFILE=${MAKEFILE:-"$ROOT/Makefile"}
OUT_DIR=${OUT_DIR:-"$ROOT/dist"}

usage() {
	printf '%s\n' "Usage: $0 [--output DIR] [--version VERSION] [--release RELEASE]"
}

version=$(sed -n 's/^PKG_VERSION:=//p' "$MAKEFILE" | head -n 1)
release=$(sed -n 's/^PKG_RELEASE:=//p' "$MAKEFILE" | head -n 1 | tr -d '[:space:]')

while [ "$#" -gt 0 ]; do
	case "$1" in
		--output)
			[ "$#" -ge 2 ] || { usage >&2; exit 2; }
			OUT_DIR=$2
			shift 2
			;;
		--version)
			[ "$#" -ge 2 ] || { usage >&2; exit 2; }
			version=$2
			shift 2
			;;
		--release)
			[ "$#" -ge 2 ] || { usage >&2; exit 2; }
			release=$2
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			usage >&2
			exit 2
			;;
	esac
done

[ -n "$version" ] || { echo "PKG_VERSION is empty" >&2; exit 1; }
[ -n "$release" ] || { echo "PKG_RELEASE is empty" >&2; exit 1; }
[ -f "$ROOT/opt/etc/ndm/fs.d/15-kvas-start.sh" ] || { echo "missing KVAS source tree" >&2; exit 1; }
[ -f "$ROOT/opt/etc/ndm/netfilter.d/100-dns-local" ] || { echo "missing KVAS source tree" >&2; exit 1; }
[ -f "$ROOT/opt/etc/init.d/S96kvas" ] || { echo "missing KVAS source tree" >&2; exit 1; }

depends=$(sed -n 's/^\s*DEPENDS:=[[:space:]]*//p' "$MAKEFILE" | tail -n 1 | tr -s '[:space:]' '\n' | sed '/^$/d; s/^+//' | awk 'NR == 1 { printf "%s", $0; next } { printf ", %s", $0 }')
pkg_version=${version}-${release}
pkg_name=kvas_${pkg_version}_all.ipk

work=$(mktemp -d "${TMPDIR:-/tmp}/kvas-ipk.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

stage=$work/stage
mkdir -p "$stage/opt/apps/kvas" "$stage/opt/etc/init.d" \
	"$stage/opt/etc/ndm/fs.d" "$stage/opt/etc/ndm/netfilter.d"

# This mirrors Package/kvas/install in the upstream Makefile:
# opt/. is installed below /opt/apps/kvas, while these three hooks are
# installed at the router's global /opt/etc locations.
cp -a "$ROOT/opt/." "$stage/opt/apps/kvas/"
cp -a "$ROOT/opt/etc/init.d/S96kvas" "$stage/opt/etc/init.d/"
cp -a "$ROOT/opt/etc/ndm/fs.d/15-kvas-start.sh" "$stage/opt/etc/ndm/fs.d/"
cp -a "$ROOT/opt/etc/ndm/netfilter.d/100-dns-local" "$stage/opt/etc/ndm/netfilter.d/"

control_dir=$work/control
mkdir -p "$control_dir"
cat > "$control_dir/control" <<EOF
Package: kvas
Version: $pkg_version
Depends: $depends
Source: https://github.com/qzeleza/kvas
Maintainer: mail@zeleza.ru
Architecture: all
Description: VPN клиент для Keenetic (v$release)
Section: utils
Priority: optional
Installed-Size: $(du -sk "$stage/opt/apps/kvas" | awk '{print $1}')
EOF

sed -n '/^define Package\/kvas\/postinst$/,/^endef$/ {/^define /d; /^endef$/d; p;}' \
	"$MAKEFILE" | sed '1{/^$/d;}' > "$control_dir/postinst"

[ -s "$control_dir/postinst" ] || { echo "failed to extract postinst" >&2; exit 1; }
# OpenWrt normally expands these Make variables while generating postinst.
# This standalone builder must perform the same substitution itself.
sed -i \
	-e "s/\\\$(PKG_VERSION)/$version/g" \
	-e "s/\\\$(PKG_RELEASE)/$release/g" \
	"$control_dir/postinst"
chmod 0755 "$control_dir/postinst"

printf '2.0\n' > "$work/debian-binary"

tar --sort=name --mtime='1970-01-01 00:00:00Z' --owner=0 --group=0 --numeric-owner \
	-czf "$work/data.tar.gz" -C "$stage" .
tar --sort=name --mtime='1970-01-01 00:00:00Z' --owner=0 --group=0 --numeric-owner \
	-czf "$work/control.tar.gz" -C "$control_dir" control postinst

mkdir -p "$OUT_DIR"
tar --sort=name --mtime='1970-01-01 00:00:00Z' --owner=0 --group=0 --numeric-owner \
	-czf "$OUT_DIR/$pkg_name" -C "$work" debian-binary control.tar.gz data.tar.gz

test -s "$OUT_DIR/$pkg_name"
printf '%s\n' "$OUT_DIR/$pkg_name"
