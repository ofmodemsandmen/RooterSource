#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "Wireguard Stop" "$@"
}

WG=$1

SERVE=$(uci get wireguard."$WG".client)
if [ $SERVE = "0" ]; then
	ifdown wg1
	uci set wireguard.settings.server="0"
else
	ifdown wg0
	uci set wireguard.settings.client="0"
fi
UDP=$(uci get wireguard."$WG".udptunnel)
if [ $UDP = 1 ]; then
	PID=$(ps |grep "udptunnel" | grep -v grep |head -n 1 | awk '{print $1}')
	kill -9 $PID
fi

uci set wireguard."$WG".active="0"
uci commit wireguard

/etc/init.d/wireguard stop