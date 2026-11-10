#!/bin/sh

set -u

STATE=/opt/rescue/kvas-vless-rollback/state

if [ ! -r "${STATE}" ]; then
	echo "Нет сохранённого состояния VLESS rollback: ${STATE}" >&2
	exit 1
fi

. "${STATE}"

case "${OLD_INFACE_CLI:-}" in
	*[!A-Za-z0-9_.:+/-]*|"")
		echo "Состояние rollback содержит недопустимый CLI-интерфейс" >&2
		exit 1
	;;
esac
case "${OLD_INFACE_ENT:-}" in
	*[!A-Za-z0-9_.:+/-]*|"")
		echo "Состояние rollback содержит недопустимый Entware-интерфейс" >&2
		exit 1
	;;
esac
case "${OLD_ADDR_MAN:-}" in
	*[!A-Za-z0-9_.:+/-]*)
		echo "Состояние rollback содержит недопустимый ADDR_MAN" >&2
		exit 1
	;;
esac

. /opt/apps/kvas/bin/libs/main
. /opt/apps/kvas/bin/libs/vpn

if [ -n "${OLD_ADDR_MAN:-}" ]; then
	set_config_value ADDR_MAN "${OLD_ADDR_MAN}"
else
	set_config_value ADDR_MAN ""
fi

/opt/etc/init.d/S97xray stop >/dev/null 2>&1 || true
is_install_stage=rollback

if ! switch_vpn_on "${OLD_INFACE_ENT}" "${OLD_INFACE_CLI}"; then
	echo "Не удалось восстановить ${OLD_INFACE_CLI}/${OLD_INFACE_ENT}" >&2
	echo "Проверьте WAN и используйте штатный rescue netfix при необходимости." >&2
	exit 1
fi

echo "Rollback к ${OLD_INFACE_CLI} завершён. Проверьте:"
echo "  /opt/bin/kvas vpn"
echo "  ndmc -c 'show interface ${OLD_INFACE_CLI}'"
echo "  ip route get 1.1.1.1"
echo "  ip route show table 1001"
