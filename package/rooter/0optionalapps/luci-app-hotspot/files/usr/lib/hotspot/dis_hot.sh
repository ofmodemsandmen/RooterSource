#!/bin/sh
. /lib/functions.sh

rm -f /tmp/hotman
uci -q set wireless.wwan.ssid="Disconnected"
uci -q set wireless.wwan.disabled=1
uci -q commit wireless
ifdown wwan
ubus call network reload
