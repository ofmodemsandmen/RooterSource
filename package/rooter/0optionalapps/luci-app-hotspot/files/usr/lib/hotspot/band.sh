#!/bin/sh 

log() {
	logger -t "band change" "$@"
}

BAND=$1

if [ $BAND = "1" ]; then
	WW=$(uci get travelmate.global.radio24)
else
	WW=$(uci get travelmate.global.radio5)
fi
wifi up
uci set wireless.wwan.device=$WW
uci set wireless.wwan.ssid="Wifi Radio is currently changing"
uci set wireless.wwan.encryption="none"
uci set wireless.wwan.disabled="1"
uci commit wireless
wifi up
result=`ps | grep -i "travelmate.sh" | grep -v "grep" | wc -l`
if [ $result -ge 1 ]
then
	logger -t TRAVELMATE-DEBUG "Travelmate already running"
else
	/usr/lib/hotspot/travelmate.sh &
fi
sleep 10
uci set wireless.wwan.ssid="Wifi Radio finished changing"
uci commit wireless
exit 0