#!/bin/sh

. /lib/functions.sh

# travelmate, a wlan connection manager for travel router
# written by Dirk Brenken (dev@brenken.org)

# This is free software, licensed under the GNU General Public License v3.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

# prepare environment
#
LC_ALL=C
PATH="/usr/sbin:/usr/bin:/sbin:/bin"
trm_ver="0.3.0"
trm_enabled=1
trm_debug=0
trm_maxwait=20
trm_maxretry=3
trm_iw=1
trm_auto=0

RADIO="radio0"

do_radio() {
	local config=$1
	local channel

	config_get channel $1 channel
	if [ $channel -lt 15 ]; then
		RADIO=$config
	fi
}

check_wwan() {
	while [ ! -e /etc/config/wireless ]
	do
		sleep 1
	done
	sleep 3
	WW=$(uci get wireless.wwan)
	if [ -z $WW ]; then
		config_load wireless
		config_foreach do_radio wifi-device
		uci set wireless.wwan=wifi-iface
		uci set wireless.wwan.device=$RADIO
		uci set wireless.wwan.network="wwan"
		uci set wireless.wwan.mode="sta"
		uci set wireless.wwan.ssid="No Connection"
		uci set wireless.wwan.encryption="none"
		uci set wireless.wwan.disabled="1"
		uci commit wireless
		f_log "info " "status  ::: Hotspot Manager restarting Wifi and Network"
		#wifi down
		wifi up
		/etc/init.d/network restart
	fi
}

do_radio24() {
	local config=$1
	local channel

	config_get channel $1 channel
	if [ $channel -gt 15 ]; then
		uci set travelmate.global.radio5=$config
	else
		uci set travelmate.global.radio24=$config
	fi
}

check_radio() {
#	WW=$(uci get travelmate.global.radio24)
#		if [ -z $WW ]; then
			config_load wireless
			config_foreach do_radio24 wifi-device
			uci commit travelmate
#		fi
}
f_envload()
{
    # source required system libraries
    #
    if [ -r "/lib/functions.sh" ]
    then
        . "/lib/functions.sh"
    else
        f_log "error" "required system library not found"
    fi

    # load uci config and check 'enabled' option
    #
    option_cb()
    {
        local option="${1}"
        local value="${2}"
        eval "${option}=\"${value}\""
    }
    config_load travelmate

    if [ ${trm_enabled} -ne 1 ]
    then
        f_log "info " "status  ::: Hotspot Manager is currently disabled"
        exit 0
    fi

    # check for preferred wireless tool
    #
    if [ ${trm_iw} -eq 1 ]
    then
        trm_scanner="$(which iw)"
    else
        trm_scanner="$(which iwinfo)"
    fi
    if [ -z "${trm_scanner}" ]
    then
        f_log "error" "status  ::: no wireless tool for wlan scanning found, please install 'iw' or 'iwinfo'"
    fi
}

# function to bring down all STA interfaces
#
f_prepare()
{
    local config="${1}"
    local mode="$(uci -q get wireless."${config}".mode)"
    local network="$(uci -q get wireless."${config}".network)"
    local disabled="$(uci -q get wireless."${config}".disabled)"

    if [ "${mode}" = "sta" ] && [ -n "${network}" ]
    then
        trm_stalist="${trm_stalist} ${config}_${network}"
        if [ -z "${disabled}" ] || [ "${disabled}" = "0" ]
        then
            uci -q set wireless."${config}".disabled=1
            f_log "debug" "prepare ::: config: ${config}, interface: ${network}"
        fi
    fi
}

f_check()
{
    local ifname cnt=0 mode="${1}"
    trm_ifstatus="false"

    while [ ${cnt} -lt ${trm_maxwait} ]
    do
		RADIO=$(uci get wireless.wwan.device)
		if [ $RADIO = "radio0" ]; then
			ifname="$(ubus -S call network.wireless status | jsonfilter -l 1 -e "@.radio0.interfaces[@.config.mode=\"${mode}\"].ifname")"
		else
			if [ $RADIO = "radio1" ]; then
				ifname="$(ubus -S call network.wireless status | jsonfilter -l 1 -e "@.radio1.interfaces[@.config.mode=\"${mode}\"].ifname")"
			fi
		fi
	if [ -z $ifname ]; then
		break
	fi
        if [ "${mode}" = "sta" ]
        then
			trm_ifstatus="$(ubus -S call network.interface dump | jsonfilter -e "@.interface[@.device=\"${ifname}\"].up")"
        else
            trm_ifstatus="$(ubus -S call network.wireless status | jsonfilter -l1 -e '@.*.up')"
        fi
        if [ "${trm_ifstatus}" = "true" ]
        then
            break
        fi
        cnt=$((cnt+1))
        sleep 1
    done
    f_log "debug" "check   ::: ${mode} name: ${ifname}, status: ${trm_ifstatus}, count: ${cnt}"
}

# function to write to syslog
#
f_log()
{
    local class="${1}"
    local log_msg="${2}"

    if [ -n "${log_msg}" ] && ([ "${class}" != "debug" ] || [ ${trm_debug} -eq 1 ])
    then
        logger -t "HOTSPOT-[${trm_ver}] ${class}" "${log_msg}"
        if [ "${class}" = "error" ]
        then
		uci -q set wireless.wwan.ssid="Error during Connection"
		uci -q set wireless.wwan.encryption="none"
		uci -q set wireless.wwan.key=
      		uci -q commit wireless
            #exit 255
        fi
    fi
}

f_main()
{
    local ap_list ssid_list config network ssid cnt=0

    f_check "sta"
    if [ "${trm_ifstatus}" != "true" ]
    then
	uci -q set wireless.wwan.ssid="Checking for Connection"
	uci -q set wireless.wwan.encryption="none"
	uci -q set wireless.wwan.key=
       uci -q commit wireless

        config_load wireless
        config_foreach f_prepare wifi-iface
        if [ -n "$(uci -q changes wireless)" ]
        then
            uci -q commit wireless
            ubus call network reload
        fi
        f_check "ap"
        RADIO=$(uci get wireless.wwan.device)
		if [ $RADIO = "radio0" ]; then
			ap_list="$(ubus -S call network.wireless status | jsonfilter -e '@.radio0.interfaces[@.config.mode="ap"].ifname')"
		else
			ap_list="$(ubus -S call network.wireless status | jsonfilter -e '@.radio1.interfaces[@.config.mode="ap"].ifname')"
		fi
        f_log "debug" "main    ::: ap-list: ${ap_list}, sta-list: ${trm_stalist}"
        if [ -z "${ap_list}" ] || [ -z "${trm_stalist}" ]
        then
            f_log "error" "main    ::: no usable AP/STA configuration found"
        else
        for ap in ${ap_list}
        do
            while [ ${cnt} -lt ${trm_maxretry} ]
            do
                if [ ${trm_iw} -eq 1 ]
                then
                    ssid_list="$(${trm_scanner} dev "${ap}" scan 2>/dev/null | \
                        awk '/SSID: /{if(!seen[$0]++){printf "\"";for(i=2; i<=NF; i++)if(i==2)printf $i;else printf " "$i;printf "\" "}}')"
                else
                    ssid_list="$(${trm_scanner} "${ap}" scan | \
                        awk '/ESSID: ".*"/{ORS=" ";if (!seen[$0]++) for(i=2; i<=NF; i++) print $i}')"
                fi
                f_log "debug" "main    ::: scan-tool: ${trm_scanner}, ssidlist: ${ssid_list}"
                if [ -n "${ssid_list}" ]
                then
			if [ "$trm_auto" = "1" ]; then
				FILE="/etc/hotspot"
			else
				FILE="/tmp/hotman"
			fi
			if [ -f "${FILE}" ]; then
                    		while IFS='|' read -r ssid encrypt key
                   		do
					ssidq="\"$ssid\""
                     		if [ -n "$(printf "${ssid_list}" | grep -Fo "${ssidq}")" ]
                     		then
						uci -q set wireless.wwan.ssid="$ssid"
						uci -q set wireless.wwan.encryption=$encrypt
						uci -q set wireless.wwan.key=$key
                           			uci -q set wireless.wwan.disabled=0
                            		uci -q commit wireless
                            		ubus call network.interface.wwan up
                            		ubus call network reload
                            		f_log "info " "main    ::: wwan interface connected to uplink ${ssid}"
						sleep 5						
						f_check "sta"
    						if [ "${trm_ifstatus}" = "true" ]
   						 then
                            			exit 0
						fi
						uci -q set wireless.wwan.ssid="Connection Failed"
						uci -q set wireless.wwan.encryption="none"
						uci -q set wireless.wwan.key=
                           			uci -q set wireless.wwan.disabled=1
                            		uci -q commit wireless
                        		fi
                    		done <"${FILE}"
			fi
                fi
                cnt=$((cnt+1))
                sleep 5
            done
        done
	fi
	if [ "$trm_auto" = "1" ]; then
		uci -q set wireless.wwan.ssid="No Connection Found, Rechecking"
	else
		uci -q set wireless.wwan.ssid="No Connection Made"
	fi
	uci -q set wireless.wwan.encryption="none"
	uci -q set wireless.wwan.key=
       uci -q commit wireless
        f_log "info " "main    ::: no wwan uplink found"
	return 0
    fi
	exit 0
}

check_wwan
check_radio
f_envload
f_main
while [ "$trm_auto" = "1" ]; do
	sleep 20
	f_main
	f_envload
done

exit 0