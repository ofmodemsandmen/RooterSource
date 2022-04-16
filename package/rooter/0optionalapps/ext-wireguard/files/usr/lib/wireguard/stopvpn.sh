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
	uci delete network.wg1
	uci set network.wg1=interface
	uci set network.wg1.proto="wireguard"
	uci set network.wg1.auto="0"
	uci set network.wg1.private_key=""
	uci set network.wg1.listen_port=""
	uci add_list network.wg1.addresses=""
	uci commit network
else
	ifdown wg0
	uci set wireguard.settings.client="0"
	uci delete network.wg0
	uci set network.wg0=interface
	uci set network.wg0.proto="wireguard"
	uci set network.wg0.auto="0"
	uci set network.wg0.private_key=""
	uci set network.wg0.listen_port=""
	uci add_list network.wg0.addresses=""
	uci commit network
fi
UDP=$(uci get wireguard."$WG".udptunnel)
if [ $UDP = 1 ]; then
	PID=$(ps |grep "udptunnel" | grep -v grep |head -n 1 | awk '{print $1}')
	kill -9 $PID
fi

uci set wireguard."$WG".active="0"
uci commit wireguard

/etc/init.d/wireguard stop