#!/bin/sh
append DRIVERS "mac80211"

lookup_phy() {
	[ -n "$phy" ] && {
		[ -d /sys/class/ieee80211/$phy ] && return
	}

	local devpath
	config_get devpath "$device" path
	[ -n "$devpath" ] && {
		for phy in $(ls /sys/class/ieee80211 2>/dev/null); do
			case "$(readlink -f /sys/class/ieee80211/$phy/device)" in
				*$devpath) return;;
			esac
		done
	}

	local macaddr="$(config_get "$device" macaddr | tr 'A-Z' 'a-z')"
	[ -n "$macaddr" ] && {
		for _phy in /sys/class/ieee80211/*; do
			[ -e "$_phy" ] || continue

			[ "$macaddr" = "$(cat ${_phy}/macaddress)" ] || continue
			phy="${_phy##*/}"
			return
		done
	}
	phy=
	return
}

find_mac80211_phy() {
	local device="$1"

	config_get phy "$device" phy
	lookup_phy
	[ -n "$phy" -a -d "/sys/class/ieee80211/$phy" ] || {
		echo "PHY for wifi device $1 not found"
		return 1
	}
	config_set "$device" phy "$phy"

	config_get macaddr "$device" macaddr
	[ -z "$macaddr" ] && {
		config_set "$device" macaddr "$(cat /sys/class/ieee80211/${phy}/macaddress)"
	}

	return 0
}

check_mac80211_device() {
	config_get phy "$1" phy
	[ -z "$phy" ] && {
		find_mac80211_phy "$1" >/dev/null || return 0
		config_get phy "$1" phy
	}
	[ "$phy" = "$dev" ] && found=1
}

detect_mac80211() {
	devidx=0
	config_load wireless
	while :; do
		config_get type "radio$devidx" type
		[ -n "$type" ] || break
		devidx=$(($devidx + 1))
	done

	for _dev in /sys/class/ieee80211/*; do
		[ -e "$_dev" ] || continue

		dev="${_dev##*/}"

		found=0
		config_foreach check_mac80211_device wifi-device
		[ "$found" -gt 0 ] && continue

		mode_band="g"
		channel="11"
		htmode=""
		ht_capab=""

		iw phy "$dev" info | grep -q 'Capabilities:' && htmode=HT40

		iw phy "$dev" info | grep -q '5180 MHz' && {
			iw phy "$dev" info | grep -q 'VHT Capabilities' && htmode="VHT80"
			t4=$(iw phy "$dev" info | grep '2412 MHz')
			if [ ! -z "$t4" ]; then
				if [ $htmode = "VHT80" ]; then
					mode_band="a"
					channel="36"
				else
					htmode="HT40"
				fi
			else
				mode_band="a"
				channel="36"
			fi
		}

		[ -n "$htmode" ] && ht_capab="set wireless.radio${devidx}.htmode=$htmode"

		if [ -x /usr/bin/readlink -a -h /sys/class/ieee80211/${dev} ]; then
			path="$(readlink -f /sys/class/ieee80211/${dev}/device)"
		else
			path=""
		fi
		if [ -n "$path" ]; then
			path="${path##/sys/devices/}"
			case "$path" in
				platform*/pci*) path="${path##platform/}";;
			esac
			dev_id="set wireless.radio${devidx}.path='$path'"
		else
			dev_id="set wireless.radio${devidx}.macaddr=$(cat /sys/class/ieee80211/${dev}/macaddress)"
		fi

		if [ -e /etc/customwifi ]; then
			I=0
			while IFS=$'\n' read -r line
			do
				if [ $I = 0 ];then
					SSID="$line"
					I=1
				else
					if [ $I = 1 ];then
						SSID5G="$line"
						I=2
					else
						PASSW="$line"
						break
					fi
				fi

			done < /etc/customwifi
		else
			SSID="ROOter"
			SSID5G="ROOter 5G"
			PASSW="rooter2017"
		fi
		if [ $channel = "11" ]; then
			SSID="$SSID"
		else
			SSID="$SSID5G"
		fi
		if [ "$channel" = 36 ]; then
			channel=44
		fi

		uci -q batch <<-EOF
			set wireless.radio${devidx}=wifi-device
			set wireless.radio${devidx}.type=mac80211
			set wireless.radio${devidx}.channel=${channel}
			set wireless.radio${devidx}.hwmode=11${mode_band}
			${dev_id}
			${ht_capab}
			set wireless.radio${devidx}.disabled=0
			set wireless.radio${devidx}.noscan=1
			set wireless.radio${devidx}.country='US'
			set wireless.radio${devidx}.txpower=20

			set wireless.default_radio${devidx}=wifi-iface
			set wireless.default_radio${devidx}.device=radio${devidx}
			set wireless.default_radio${devidx}.network=lan
			set wireless.default_radio${devidx}.mode=ap
			set wireless.default_radio${devidx}.ssid='$SSID'
			set wireless.default_radio${devidx}.encryption=psk2
			set wireless.default_radio${devidx}.key=$PASSW
EOF
		uci -q commit wireless

		devidx=$(($devidx + 1))
	done
}
