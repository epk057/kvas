#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/kvas-safety-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

sh -n "$ROOT/opt/bin/libs/vpn"
sh -n "$ROOT/opt/bin/libs/vless"
sh -n "$ROOT/opt/etc/ndm/ndm"

grep -Fq 'state=$(get_value_interface_field "${inface_cli}" state)' "$ROOT/opt/bin/libs/vpn"
grep -Fq 'link=$(get_value_interface_field "${inface_cli}" link)' "$ROOT/opt/bin/libs/vpn"
grep -Fq 'connected=$(get_value_interface_field "${inface_cli}" connected)' "$ROOT/opt/bin/libs/vpn"
grep -Fq 'update_iptables || exit 1' "$ROOT/opt/bin/libs/vpn"
grep -Fq 'VLESS: вспомогательный /24 маршрут' "$ROOT/opt/etc/ndm/ndm"
grep -Fq 'ip4__mark__create_chain || return 1' "$ROOT/opt/etc/ndm/ndm"
grep -Fq 'XRAY_INIT=/opt/etc/init.d/S97xray' "$ROOT/opt/bin/libs/vless"
! grep -Fq "service_restart 'клиент VLESS' 'S24xray'" "$ROOT/opt/bin/libs/vpn"
grep -Fq 'RULE_PRIORITY=99' "$ROOT/opt/etc/ndm/ndm"
grep -Fq 'Не передёргивать Proxy21 через RCI' "$ROOT/opt/bin/libs/vpn"
grep -Fq 'повторный RCI-up VLESS запрещён' "$ROOT/opt/etc/ndm/iflayerchanged.d/100-kvas-vpn"
grep -Fq 'повторный link_reboot VLESS запрещён' "$ROOT/opt/etc/ndm/ifstatechanged.d/100-kvas-vpn"
grep -Fq 'повторный link_reboot VLESS запрещён' "$ROOT/opt/etc/ndm/iflayerchanged.d/kvas-ips-reset"
grep -Fq 'RCI down/up Proxy21 запрещён' "$ROOT/opt/bin/main/check_vpn"
grep -Fq 'Основной WAN default route отсутствует' "$ROOT/opt/etc/ndm/ndm"

ipk=$("$ROOT/tools/build-ipk.sh" --compat-352 --output "$TMP")
"$ROOT/tools/verify-compat-ipk.sh" "$ipk"

printf '%s\n' 'OK: проверки безопасности VLESS и сборки IPK пройдены'
