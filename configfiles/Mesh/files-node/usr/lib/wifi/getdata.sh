#!/bin/sh
. /lib/functions.sh

twoghz=""
fiveghz=""
do_radio() {
	local config=$1
	
	local chan=$(iwinfo $config freqlist)
	two=$(echo "$chan" | grep "2.412 GHz (Channel 1)")
	if [ ! -z "$two" ]; then
		twoghz=$1
	else
		fiveghz=$1
	fi
}

config_load wireless
config_foreach do_radio wifi-device

dual="0"
if [ ! -z "$fiveghz" ]; then
	dual="1"
fi
echo "$dual" > /tmp/wifisettings
echo "$twoghz" >> /tmp/wifisettings
twodisabled=$(uci -q get wireless.$twoghz.disabled)
echo "$twodisabled" >> /tmp/wifisettings
twonoscan=$(uci -q get wireless.$twoghz.noscan)
if [ -z "$twonoscan" ]; then
	twonoscan="0"
fi
echo "$twonoscan" >> /tmp/wifisettings
twossid=$(uci -q get wireless.default_$twoghz.ssid)
echo "$twossid" >> /tmp/wifisettings
twokey=$(uci -q get wireless.default_$twoghz.key)
if [ -z "$twokey" ]; then
	twokey="-"
fi
echo "$twokey" >> /tmp/wifisettings
twoencryption=$(uci -q get wireless.default_$twoghz.encryption)
case $twoencryption in
	"psk2" )
		twoencryption="0"
	;;
	"pskmixed" )
		twoencryption="1"
	;;
	"psk" )
		twoencryption="2"
	;;
	"none" )
		twoencryption="3"
	;;
esac
echo "$twoencryption" >> /tmp/wifisettings
twomode=$(uci -q get wireless.$twoghz.htmode)
if [ -z "$twomode" ]; then
	twomode="0"
else
	twomode="1"
fi
echo "$twomode" >> /tmp/wifisettings
twochannel=$(uci -q get wireless.$twoghz.channel)
echo "$twochannel" >> /tmp/wifisettings
chsel=""
iwinfo $twoghz freqlist > /tmp/freqlist
while IFS= read -r line; do
	line=$(echo "$line" | tr -d '*')
	line=$(echo "$line" | tr -d '[:blank:]')
	chn=$(echo $line | tr " " ',')
	chn=$(echo $chn | tr -d "(")
	chn=$(echo $chn | tr -d ")")
	channel=$(echo $chn | cut -d, -f4)
	cstr="Ch "$channel" ("$(echo $chn | cut -d, -f1)" "$(echo $chn | cut -d, -f2)")"
	if [ -z "$chsel" ]; then
		chsel=$channel"!$cstr"
	else
		chsel=$chsel"|"$channel"!$cstr"
	fi
done < /tmp/freqlist
echo "$chsel" >> /tmp/wifisettings
htmode="0"
iwinfo $twoghz htmodelist > /tmp/htmodelist
while IFS= read -r line; do
	ht40=$(echo "$line" | grep "HT40")
	if [ ! -z "$ht40" ]; then
		htmode="1"
		break
	fi
done < /tmp/htmodelist
echo "$htmode" >> /tmp/wifisettings
hmode="0"
twomode=$(uci -q get wireless.$twoghz.htmode)
ht40=$(echo "$twomode" | grep "HT40")
if [ ! -z "$ht40" ]; then
	hmode="1"
fi
echo "$hmode" >> /tmp/wifisettings
iwinfo $twoghz txpowerlist > /tmp/txpowerlist
txcnt=0
txsel=""
chsel=""
while IFS= read -r line; do
	curtx=$(echo "$line" | grep "*")
	if [ ! -z "$curtx" ]; then
		ctx=$txcnt
	fi
	line=$(echo "$line" | tr -d '*')
	line=$(echo "$line" | tr -d '[:blank:]')
	if [ -z "$chsel" ]; then
		chsel=$txcnt"!$line"
	else
		chsel=$chsel"|"$txcnt"!$line"
	fi
	let txcnt=$txcnt+1
done < /tmp/txpowerlist

echo "$ctx" >> /tmp/wifisettings
echo "$chsel" >> /tmp/wifisettings
echo "$txcnt" >> /tmp/wifisettings
twocountry=$(uci -q get wireless.$twoghz.country)
if [ -z "$twocountry" ]; then
	twocountry="00"
fi
echo "$twocountry" >> /tmp/wifisettings

if [ ! -z "$fiveghz" ]; then
	echo "$fiveghz" >> /tmp/wifisettings
	fivedisabled=$(uci -q get wireless.$fiveghz.disabled)
	echo "$fivedisabled" >> /tmp/wifisettings
	fivenoscan=$(uci -q get wireless.$fiveghz.noscan)
	if [ -z "$fivenoscan" ]; then
		fivenoscan="0"
	fi
	echo "$fivenoscan" >> /tmp/wifisettings
	fivessid=$(uci -q get wireless.default_$fiveghz.ssid)
	echo "$fivessid" >> /tmp/wifisettings
	fivekey=$(uci -q get wireless.default_$fiveghz.key)
	if [ -z "$fivekey" ]; then
		fivekey="-"
	fi
	echo "$fivekey" >> /tmp/wifisettings
	fiveencryption=$(uci -q get wireless.default_$fiveghz.encryption)
	case $fiveencryption in
		"psk2" )
			fiveencryption="0"
		;;
		"pskmixed" )
			fiveencryption="1"
		;;
		"psk" )
			fiveencryption="2"
		;;
		"none" )
			fiveencryption="3"
		;;
	esac
	echo "$fiveencryption" >> /tmp/wifisettings
	fivemode=$(uci -q get wireless.$fiveghz.htmode)
	if [ -z "$fivemode" ]; then
		fivemode="0"
	else
		ac=$(echo "$fivemode" | grep "VHT")
		if [ ! -z "$ac" ]; then
			fivemode="2"
		else
			fivemode="1"
		fi
	fi
	echo "$fivemode" >> /tmp/wifisettings
	fivechannel=$(uci -q get wireless.$fiveghz.channel)
	echo "$fivechannel" >> /tmp/wifisettings
	chsel=""
	iwinfo $fiveghz freqlist > /tmp/freqlist
	while IFS= read -r line; do
		line=$(echo "$line" | tr -d '*')
		line=$(echo "$line" | tr -d '[:blank:]')
		chn=$(echo $line | tr " " ',')
		chn=$(echo $chn | tr -d "(")
		chn=$(echo $chn | tr -d ")")
		channel=$(echo $chn | cut -d, -f4)
		cstr="Ch "$channel" ("$(echo $chn | cut -d, -f1)" "$(echo $chn | cut -d, -f2)")"
		if [ -z "$chsel" ]; then
			chsel=$channel"!$cstr"
		else
			chsel=$chsel"|"$channel"!$cstr"
		fi
	done < /tmp/freqlist
	echo "$chsel" >> /tmp/wifisettings
	htmode="0"
	iwinfo $fiveghz htmodelist > /tmp/htmodelist
	while IFS= read -r line; do
		ht40=$(echo "$line" | grep "VHT40")
		if [ ! -z "$ht40" ]; then
			htmode="1"
		fi
		ht40=$(echo "$line" | grep "VHT80")
		if [ ! -z "$ht40" ]; then
			htmode="2"
		fi
		ht40=$(echo "$line" | grep "VHT160")
		if [ ! -z "$ht40" ]; then
			htmode="3"
		fi
		break
	done < /tmp/htmodelist
	echo "$htmode" >> /tmp/wifisettings
	hmode="0"
	fivemode=$(uci -q get wireless.$fiveghz.htmode)
	ht40=$(echo "$fivemode" | grep "VHT40")
	if [ ! -z "$ht40" ]; then
		hmode="1"
	fi
	ht40=$(echo "$fivemode" | grep "VHT80")
	if [ ! -z "$ht40" ]; then
		hmode="2"
	fi
	ht40=$(echo "$fivemode" | grep "VHT160")
	if [ ! -z "$ht40" ]; then
		hmode="3"
	fi
	echo "$hmode" >> /tmp/wifisettings
	iwinfo $fiveghz txpowerlist > /tmp/txpowerlist
	txcnt=0
	txsel=""
	chsel=""
	while IFS= read -r line; do
		curtx=$(echo "$line" | grep "*")
		if [ ! -z "$curtx" ]; then
			ctx=$txcnt
		fi
		line=$(echo "$line" | tr -d '*')
		line=$(echo "$line" | tr -d '[:blank:]')
		if [ -z "$chsel" ]; then
			chsel=$txcnt"!$line"
		else
			chsel=$chsel"|"$txcnt"!$line"
		fi
		let txcnt=$txcnt+1
	done < /tmp/txpowerlist

	echo "$ctx" >> /tmp/wifisettings
	echo "$chsel" >> /tmp/wifisettings
	echo "$txcnt" >> /tmp/wifisettings
	fivecountry=$(uci -q get wireless.$fiveghz.country)
	if [ -z "$fivecountry" ]; then
		fivecountry="00"
	fi
	echo "$fivecountry" >> /tmp/wifisettings
fi