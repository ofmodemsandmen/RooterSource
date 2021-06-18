#!/bin/sh

RADIO=$(uci get wireless.wwan.device)
if [ $RADIO = "radio0" ]; then
	ap_list="$(ubus -S call network.wireless status | jsonfilter -e '@.radio0.interfaces[@.config.mode="ap"].ifname')"
else
	if [ $RADIO = "radio1" ]; then
		ap_list="$(ubus -S call network.wireless status | jsonfilter -e '@.radio1.interfaces[@.config.mode="ap"].ifname')"
	fi
fi

rm -f /tmp/ssidlist
for ap in ${ap_list}
do
	iwinfo "${ap}" scan >> /tmp/ssidlist
done
