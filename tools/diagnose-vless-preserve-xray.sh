#!/bin/sh
set -u

# Не входит в IPK. По умолчанию только печатает план.
ROUTER_TMP=${ROUTER_TMP:-/opt/rescue/kvas-vless-preserve-xray}
VPN_LIB=/opt/apps/kvas/bin/libs/vpn
MAIN_LIB=/opt/apps/kvas/bin/libs/main
ROLLBACK=/opt/rescue/kvas-vless-rollback.sh
WAN_GW=${WAN_GW:-185.135.234.129}
WAN_IF=${WAN_IF:-eth2.2}
VLESS_IF=${VLESS_IF:-t2s21}
PROXY_CLI=${PROXY_CLI:-Proxy21}
EXECUTE=no
TEST_DOMAIN=
TEST_URL=

usage() {
	cat <<'EOF'
Безопасный тест «Xray уже работает -> активировать только Proxy21».
По умолчанию ничего не выполняет и печатает только план.
Запуск: diagnose-vless-preserve-xray.sh --execute --domain <домен> [--url <URL>]
Сценарий проверяет OpenVPN/WAN и требует заранее запущенные Xray/SOCKS5,
сохраняет rollback-state, вызывает только vpn_on t2s21 (без service start и
без kvas vpn set vless), собирает состояние и в конце возвращает OpenVPN.
EOF
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--execute) EXECUTE=yes ;;
		--domain) [ "$#" -ge 2 ] || exit 2; TEST_DOMAIN=$2; shift ;;
		--url) [ "$#" -ge 2 ] || exit 2; TEST_URL=$2; shift ;;
		-h|--help) usage; exit 0 ;;
		*) echo "Неизвестный аргумент: $1" >&2; usage >&2; exit 2 ;;
	esac
	shift
done

if [ "$EXECUTE" != yes ]; then
	usage; echo; echo "Режим подготовки: тест НЕ выполнялся."; exit 0
fi
[ -n "$TEST_DOMAIN" ] || { echo "Для запуска нужен --domain" >&2; exit 2; }
[ -n "$TEST_URL" ] || TEST_URL="https://${TEST_DOMAIN}/"

mkdir -p "$ROUTER_TMP" || exit 1
RUN_DIR="$ROUTER_TMP/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN_DIR" || exit 1
LOG="$RUN_DIR/diagnostic.log"
log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" | tee -a "$LOG"; }
run_save() {
	_name=$1; shift; log "COMMAND $_name: $*"
	"$@" > "$RUN_DIR/$_name.txt" 2>&1; _rc=$?
	cat "$RUN_DIR/$_name.txt" >> "$LOG"; log "RESULT $_name rc=$_rc"; return $_rc
}
snapshot() {
	run_save kvas-vpn /opt/bin/kvas vpn || true
	run_save route-get ip route get 1.1.1.1 || true
	run_save route-1001 ip route show table 1001 || true
	run_save rules ip rule show || true
	run_save proxy-interface ndmc -c "show interface ${PROXY_CLI}" || true
	run_save openvpn-interface ndmc -c 'show interface OpenVPN2' || true
	run_save mangle-rules iptables -t mangle -S || true
	run_save kvas-mark iptables -t mangle -L KVAS_MARK -v -n -x || true
	run_save socket-state netstat -nt || true
	run_save xray-trace sh -c 'test -r /tmp/kvas-xray-trace.log && tail -80 /tmp/kvas-xray-trace.log || true' || true
}
rollback() {
	log "ROLLBACK: восстановление предыдущего интерфейса"
	if [ -x "$ROLLBACK" ]; then "$ROLLBACK" >> "$LOG" 2>&1 || log "ROLLBACK FAILED";
	else log "ROLLBACK UNAVAILABLE: $ROLLBACK"; fi
}
log "ПРЕДУПРЕЖДЕНИЕ: выполняется контролируемое переключение Proxy21"
run_save baseline-route-get ip route get 1.1.1.1 || exit 1
grep -Fq "via ${WAN_GW} dev ${WAN_IF}" "$RUN_DIR/baseline-route-get.txt" || { log "STOP: WAN route"; exit 1; }
run_save baseline-openvpn ndmc -c 'show interface OpenVPN2' || exit 1
grep -Fq 'connected: yes' "$RUN_DIR/baseline-openvpn.txt" || { log "STOP: OpenVPN2"; exit 1; }
pidof xray >/dev/null 2>&1 || { log "STOP: Xray must already be running"; exit 1; }
netstat -ln 2>/dev/null | grep -q '127.0.0.1:1097' || { log "STOP: SOCKS 1097"; exit 1; }
run_save baseline-socks sh -c 'curl -4 --connect-timeout 5 --max-time 15 --socks5-hostname 127.0.0.1:1097 https://api.ipify.org' || { log "STOP: SOCKS5"; exit 1; }

. "$MAIN_LIB"
. "$VPN_LIB"
prepare_vless_rollback || { log "STOP: rollback-state"; exit 1; }
trap 'rollback; log "Диагностика завершена; результаты: $RUN_DIR"' EXIT INT TERM

log "До активации Proxy21: три SOCKS-проверки"
i=1
while [ "$i" -le 3 ]; do
	curl -4 --connect-timeout 5 --max-time 15 --socks5-hostname 127.0.0.1:1097 https://api.ipify.org >> "$LOG" 2>&1 || log "SOCKS precheck $i FAILED"
	i=$((i + 1))
done

log "Активируем только vpn_on ${VLESS_IF}; Xray не перезапускаем"
(
	. "$MAIN_LIB"; . "$VPN_LIB"; vpn_on "$VLESS_IF"
) >> "$LOG" 2>&1
VPN_RC=$?; log "vpn_on rc=$VPN_RC"
snapshot
getent hosts "$TEST_DOMAIN" > "$RUN_DIR/domain-resolution.txt" 2>&1 || true
log "Результат DNS для ${TEST_DOMAIN}:"; cat "$RUN_DIR/domain-resolution.txt" >> "$LOG"
log "Проверяем SOCKS5 после активации Proxy21"
curl -4 --connect-timeout 5 --max-time 15 --socks5-hostname 127.0.0.1:1097 "$TEST_URL" >> "$LOG" 2>&1 || true
log "Тест завершён; rollback выполняется через trap"
exit "$VPN_RC"
