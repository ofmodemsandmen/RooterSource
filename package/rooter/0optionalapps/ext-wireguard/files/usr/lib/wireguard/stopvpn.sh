#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "Wireguard Stop" "$@"
}

WG=$1

SERVE=$(uci get wireguard."$WG".client)
if [ $SERVE = "0" ]; then
	ifdown wg1
else
	ifdown wg0
fi
UDP=$(uci get wireguard."$WG".udptunnel)
if [ $UDP = 1 ]; then
	PID=$(ps |grep "udptunnel" | grep -v grep |head -n 1 | awk '{print $1}')
	kill -9 $PID
fi
uci set wireguard.settings.enabled="0"
uci set wireguard."$WG".active="0"
uci commit wireguard