#!/bin/sh
. /lib/functions.sh

wif=$(uci -q get travelmate.global.freq)
rm -f /tmp/hotman
rm -f /tmp/hotping
uci set travelmate.global.ssid="7"
uci set travelmate.global.state=''
uci set travelmate.global.bssid=""
uci set travelmate.global.key=''
uci commit travelmate
uci -q set wireless.wwan$wif.disabled=1
uci set wireless.wwan$wif.ssid="Hotspot Manager Interface"
uci -q commit wireless
PID=$(ps |grep "travelmate.sh" | grep -v grep |head -n 1 | awk '{print $1}')
if [ ! -z "$PID" ]; then
	kill -9 $PID
fi
/etc/init.d/network reload

