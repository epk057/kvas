#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MAKEFILE=${MAKEFILE:-"$ROOT/Makefile"}
OUT_DIR=${OUT_DIR:-"$ROOT/dist"}

usage() {
	printf '%s\n' "Usage: $0 [--output DIR] [--version VERSION] [--release RELEASE] [--surgical|--compat-352]"
}

version=$(sed -n 's/^PKG_VERSION:=//p' "$MAKEFILE" | head -n 1)
release=$(sed -n 's/^PKG_RELEASE:=//p' "$MAKEFILE" | head -n 1 | tr -d '[:space:]')
surgical=0
compat_352=0

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
		--surgical)
			surgical=1
			shift
			;;
		--compat-352)
			compat_352=1
			shift
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

if [ "$surgical" -eq 1 ] && [ "$compat_352" -eq 1 ]; then
	echo "--surgical and --compat-352 are mutually exclusive" >&2
	exit 2
elif [ "$compat_352" -eq 1 ]; then
	base_ipk="$ROOT/kvas_1.1.9_beta-10-352_all.ipk"
	[ -f "$base_ipk" ] || { echo "missing beta-10-352 base IPK" >&2; exit 1; }
	base=$work/base
	mkdir -p "$base"
	tar -xzf "$base_ipk" -C "$base"
	tar -xzf "$base/data.tar.gz" -C "$stage"
	# Start with the complete published 352 tree so opkg does not remove
	# package-owned files, then overlay only the reviewed safety changes.
	cp -a "$ROOT/opt/bin/libs/vpn" "$stage/opt/apps/kvas/bin/libs/vpn"
	cp -a "$ROOT/opt/bin/libs/vless" "$stage/opt/apps/kvas/bin/libs/vless"
	cp -a "$ROOT/opt/bin/kvas" "$stage/opt/apps/kvas/bin/kvas"
	cp -a "$ROOT/opt/bin/libs/failover" "$stage/opt/apps/kvas/bin/libs/failover"
	cp -a "$ROOT/opt/bin/main/check_vpn" "$stage/opt/apps/kvas/bin/main/check_vpn"
	cp -a "$ROOT/opt/etc/ndm/ndm" "$stage/opt/apps/kvas/etc/ndm/ndm"
	cp -a "$ROOT/opt/etc/ndm/ndm" "$stage/opt/apps/kvas/bin/libs/ndm"
	cp -a "$ROOT/opt/etc/ndm/iflayerchanged.d/100-kvas-vpn" \
		"$stage/opt/apps/kvas/etc/ndm/iflayerchanged.d/100-kvas-vpn"
	cp -a "$ROOT/opt/etc/ndm/iflayerchanged.d/kvas-ips-reset" \
		"$stage/opt/apps/kvas/etc/ndm/iflayerchanged.d/kvas-ips-reset"
	cp -a "$ROOT/opt/etc/ndm/ifstatechanged.d/100-kvas-vpn" \
		"$stage/opt/apps/kvas/etc/ndm/ifstatechanged.d/100-kvas-vpn"
	mkdir -p "$stage/opt/apps/kvas/rescue"
	cp -a "$ROOT/opt/apps/kvas/rescue/kvas-vless-rollback.sh" \
		"$stage/opt/apps/kvas/rescue/kvas-vless-rollback.sh"
elif [ "$surgical" -eq 1 ]; then
	# Upgrade-only package: replace only the reviewed KVAS runtime files.
	mkdir -p "$stage/opt/apps/kvas/bin/libs" "$stage/opt/apps/kvas/etc/ndm"
	cp -a "$ROOT/opt/bin/libs/vpn" "$stage/opt/apps/kvas/bin/libs/"
	cp -a "$ROOT/opt/bin/libs/vless" "$stage/opt/apps/kvas/bin/libs/"
	cp -a "$ROOT/opt/etc/ndm/ndm" "$stage/opt/apps/kvas/etc/ndm/"
	cp -a "$ROOT/opt/etc/ndm/ndm" "$stage/opt/apps/kvas/bin/libs/ndm"
else
	# This mirrors Package/kvas/install in the upstream Makefile:
	# opt/. is installed below /opt/apps/kvas, while these three hooks are
	# installed at the router's global /opt/etc locations.
	cp -a "$ROOT/opt/." "$stage/opt/apps/kvas/"
	cp -a "$ROOT/opt/etc/init.d/S96kvas" "$stage/opt/etc/init.d/"
	cp -a "$ROOT/opt/etc/ndm/fs.d/15-kvas-start.sh" "$stage/opt/etc/ndm/fs.d/"
	cp -a "$ROOT/opt/etc/ndm/netfilter.d/100-dns-local" "$stage/opt/etc/ndm/netfilter.d/"
fi

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

if [ "$compat_352" -eq 1 ]; then
	cat > "$control_dir/postinst" <<'EOF'
#!/bin/sh
set -e

# Keep the existing router configuration and do not run kvas init during an
# upgrade. The operator verifies routing and activates Proxy21 separately.
ln -sf /opt/apps/kvas/bin/kvas /opt/bin/kvas
chmod -R +x /opt/apps/kvas/bin/* 2>/dev/null || true
chmod -R +x /opt/apps/kvas/etc/init.d/* 2>/dev/null || true
chmod -R +x /opt/apps/kvas/etc/ndm/* 2>/dev/null || true
exit 0
EOF
elif [ "$surgical" -eq 1 ]; then
	cat > "$control_dir/postinst" <<'EOF'
#!/bin/sh
set -e
chmod 0755 /opt/apps/kvas/bin/libs/vpn
chmod 0755 /opt/apps/kvas/bin/libs/vless
chmod 0755 /opt/apps/kvas/etc/ndm/ndm
chmod 0755 /opt/apps/kvas/bin/libs/ndm
EOF
else
	sed -n '/^define Package\/kvas\/postinst$/,/^endef$/ {/^define /d; /^endef$/d; p;}' \
		"$MAKEFILE" | sed '1{/^$/d;}' > "$control_dir/postinst"

	[ -s "$control_dir/postinst" ] || { echo "failed to extract postinst" >&2; exit 1; }
	# OpenWrt normally expands these Make variables while generating postinst.
	# This standalone builder must perform the same substitution itself.
	sed -i \
		-e "s/\\\$(PKG_VERSION)/$version/g" \
		-e "s/\\\$(PKG_RELEASE)/$release/g" \
		"$control_dir/postinst"
fi
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
