#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	logger -t "Create Hostless Connection" "$@"
}

ifname1="ifname"
if [ -e /etc/newstyle ]; then
	ifname1="device"
fi

handle_timeout(){
	local wget_pid="$1"
	local count=0
	ps | grep -v grep | grep $wget_pid
	res="$?"
	while [ "$res" = 0 -a $count -lt "$((TIMEOUT))" ]; do
		sleep 1
		count=$((count+1))
		ps | grep -v grep | grep $wget_pid
		res="$?"
	done

	if [ "$res" = 0 ]; then
		log "Killing process on timeout"
		kill "$wget_pid" 2> /dev/null
		ps | grep -v grep | grep $wget_pid
		res="$?"
		if [ "$res" = 0 ]; then
			log "Killing process on timeout"
			kill -9 $wget_pid 2> /dev/null
		fi
	fi
}

set_dns() {
	local pDNS1=$(uci -q get modem.modeminfo$CURRMODEM.dns1)
	local pDNS2=$(uci -q get modem.modeminfo$CURRMODEM.dns2)
	local pDNS3=$(uci -q get modem.modeminfo$CURRMODEM.dns3)
	local pDNS4=$(uci -q get modem.modeminfo$CURRMODEM.dns4)

	local aDNS="$pDNS1 $pDNS2 $pDNS3 $pDNS4"
	local bDNS=""

	echo "$aDNS" | grep -o "[[:graph:]]" &>/dev/null
	if [ $? = 0 ]; then
		log "Using DNS settings from the Connection Profile"
		pdns=1
		for DNSV in $(echo "$aDNS"); do
			if [ "$DNSV" != "0.0.0.0" ] && [ -z "$(echo "$bDNS" | grep -o "$DNSV")" ]; then
				[ -n "$(echo "$DNSV" | grep -o ":")" ] && continue
				bDNS="$bDNS $DNSV"
			fi
		done

		bDNS=$(echo $bDNS)
		uci set network.wan$INTER.peerdns=0
		uci set network.wan$INTER.dns="$bDNS"
		echo "$bDNS" > /tmp/v4dns$INTER

		bDNS=""
		for DNSV in $(echo "$aDNS"); do
			if [ "$DNSV" != "0:0:0:0:0:0:0:0" ] && [ -z "$(echo "$bDNS" | grep -o "$DNSV")" ]; then
				[ -z "$(echo "$DNSV" | grep -o ":")" ] && continue
				bDNS="$bDNS $DNSV"
			fi
		done
		echo "$bDNS" > /tmp/v6dns$INTER
	else
		log "Using Hostless Modem as a DNS"
		pdns=0
		rm -f /tmp/v[46]dns$INTER
	fi
}

set_network() {
	uci delete network.wan$INTER
	uci set network.wan$INTER=interface
	uci set network.wan$INTER.proto=dhcp
	uci set network.wan$INTER.${ifname1}=$1
	uci set network.wan$INTER.metric=$INTER"0"
	set_dns
	uci commit network
	sleep 5
}

save_variables() {
	echo 'MODSTART="'"$MODSTART"'"' > /tmp/variable.file
	echo 'WWAN="'"$WWAN"'"' >> /tmp/variable.file
	echo 'USBN="'"$USBN"'"' >> /tmp/variable.file
	echo 'ETHN="'"$ETHN"'"' >> /tmp/variable.file
	echo 'WDMN="'"$WDMN"'"' >> /tmp/variable.file
	echo 'BASEPORT="'"$BASEPORT"'"' >> /tmp/variable.file
}

chcklog() {
	OOX=$1
	CLOG=$(uci -q get modem.modeminfo$CURRMODEM.log)
	if [ $CLOG = "1" ]; then
		log "$OOX"
	fi
}

get_connect() {
	NAPN=$(uci -q get modem.modeminfo$CURRMODEM.apn)
	uci set modem.modem$CURRMODEM.apn="$NAPN"
	uci commit modem
}

get_tty_fix() {
# $1 is fixed ttyUSB or ttyACM port number
	local POS
	POS=`expr 1 + $1`
	CPORT=$(echo "$TTYDEVS" | cut -d' ' -f"$POS" | grep -o "[[:digit:]]\+")
}

CURRMODEM=$1

MAN=$(uci get modem.modem$CURRMODEM.manuf)
MOD=$(uci get modem.modem$CURRMODEM.model)
$ROOTER/signal/status.sh $CURRMODEM "$MAN $MOD" "Connecting"
$ROOTER/log/logger "Attempting to Connect Modem #$CURRMODEM ($MAN $MOD)"

BASEP=$(uci -q get modem.modem$CURRMODEM.baseport)
idV=$(uci get modem.modem$CURRMODEM.idV)
idP=$(uci get modem.modem$CURRMODEM.idP)
log " "
log "Hostless ID $idV:$idP"
log " "

MDEVICE=$(uci -q get modem.modem$CURRMODEM.device)
OX=$(ls /sys/bus/usb/devices/"$MDEVICE":*/ | grep -o ttyUSB[0-9])
if [ $? -ne 0 ]; then
	log "No ECM Comm Port"
else
	TTYDEVS=$(echo "$OX" | tr '\n' ' ')
	TTYDEVS=$(echo "$TTYDEVS")
	log Modem at $MDEVICE is a parent of $TTYDEVS
fi

if [ $idV = 1546 -a $idP = 1146 ]; then
	SP=1
elif [ $idV = 19d2 -a $idP = 1476 ]; then
	SP=2
elif [ $idV = 1410 -a $idP = 9022 ]; then
	SP=3
elif [ $idV = 1410 -a $idP = 9032 ]; then
	SP=3
elif [ $idV = 2cb7 ]; then
	log "Fibocom ECM"
	SP=4
elif [ $idV = 2c7c ]; then
	SP=5
elif [ $idV = 12d1 -a $idP = 15c1 ]; then
	SP=6
else
	SP=0
fi

log " "
log "Modem Type $SP"
log " "
if [ $SP -gt 0 ]; then
	if [ $SP -eq 3 ]; then
		PORTN=0
	elif [ $SP -eq 4 ]; then
		PORTN=2
	elif [ $SP -eq 5 ]; then
		PORTN=2
	elif [ $SP -eq 6 ]; then
		PORTN=2
	else
		PORTN=1
	fi
	get_tty_fix $PORTN
	lua $ROOTER/common/modemchk.lua "$idV" "$idP" "$CPORT" "$CPORT"
	source /tmp/parmpass
	uci set modem.modem$CURRMODEM.commport=$CPORT
	uci commit modem
	log "Modem $CURRMODEM ECM Comm Port : /dev/ttyUSB$CPORT"
	$ROOTER/sms/check_sms.sh $CURRMODEM &
	$ROOTER/common/gettype.sh $CURRMODEM
	if [ $SP = 5 ]; then
		if [ -e /etc/interwave ]; then
			ATCMDD="AT+CGMM"
			MODEL=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
			EM160=$(echo $MODEL | grep "EM160")
			idV=$(uci get modem.modem$CURRMODEM.idV)
			if [ $idV != "0800" ]; then
				if [ $EM160 ]; then
					ATC="AT+QNWPREFCFG=\"mode_pref\",LTE"
				else
					ATC="AT+QCFG=\"nwscanmode\",3"
				fi
				OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
			else
				ATC="AT+QNWPREFCFG=\"mode_pref\",LTE:NR5G"
				OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATC")
			fi
		fi
		$ROOTER/connect/bandmask $CURRMODEM 1
		uci commit modem
	fi
	if [ $SP = 4 ]; then
		if [ -e /etc/interwave ]; then
			idP=$(uci -q get modem.modem$CURRMODEM.idP)
			idPP=${idP:1:1}
			if [ "$idPP" = "1" ]; then
				ATC="AT+GTRAT=17"
			else
				ATC="AT+XACT=4,2"
			fi
			OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATC")
		fi
		$ROOTER/connect/bandmask $CURRMODEM 2
		uci commit modem
	fi
fi
$ROOTER/connect/get_profile.sh $CURRMODEM

INTER=$(uci get modem.modeminfo$CURRMODEM.inter)
if [ -z $INTER ]; then
	INTER=$CURRMODEM
else
	if [ $INTER = 0 ]; then
		INTER=$CURRMODEM
	fi
fi
log "Profile for Modem $CURRMODEM sets interface to WAN$INTER"
OTHER=1
if [ $CURRMODEM = 1 ]; then
	OTHER=2
fi
EMPTY=$(uci get modem.modem$OTHER.empty)
if [ $EMPTY = 0 ]; then
	OINTER=$(uci get modem.modem$OTHER.inter)
	if [ ! -z $OINTER ]; then
		if [ $INTER = $OINTER ]; then
			INTER=1
			if [ $OINTER = 1 ]; then
				INTER=2
			fi
			log "Switched Modem $CURRMODEM to WAN$INTER as Modem $OTHER is using WAN$OINTER"
		fi
	fi
fi
uci set modem.modem$CURRMODEM.inter=$INTER
uci commit modem
log "Modem $CURRMODEM is using WAN$INTER"

log "Checking Network Interface"
MATCH="$(uci get modem.modem$CURRMODEM.maxcontrol | cut -d/ -f3- | xargs dirname)"
ifname="$(if [ "$MATCH" ]; then for a in /sys/class/net/*; do readlink $a; done | grep "$MATCH"; fi | xargs -r basename)"

if [ "$ifname" ]; then
	log "Modem $CURRMODEM ECM Data Port : $ifname"
	set_network "$ifname"
	uci set modem.modem$CURRMODEM.interface=$ifname
	if [ -e $ROOTER/changedevice.sh ]; then
		$ROOTER/changedevice.sh $ifname
	fi
else
	log "Modem $CURRMODEM - No ECM Data Port found"
fi
uci commit modem

if [ $SP -eq 2 ]; then
	get_connect
	export SETAPN=$NAPN
	BRK=1

	while [ $BRK -eq 1 ]; do
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "connect-zecm.gcom" "$CURRMODEM")
		chcklog "$OX"
		ERROR="ERROR"
		if `echo ${OX} | grep "${ERROR}" 1>/dev/null 2>&1`
		then
			$ROOTER/signal/status.sh $CURRMODEM "$MAN $MOD" "Failed to Connect : Retrying"
		else
			BRK=0
		fi
	done
fi
if [ $SP -eq 6 ]; then
	get_connect
	export SETAPN=$NAPN
	BRK=1

	while [ $BRK -eq 1 ]; do
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "connect-ncm.gcom" "$CURRMODEM")
		chcklog "$OX"
		ERROR="ERROR"
		if `echo ${OX} | grep "${ERROR}" 1>/dev/null 2>&1`
		then
			$ROOTER/signal/status.sh $CURRMODEM "$MAN $MOD" "Failed to Connect : Retrying"
		else
			BRK=0
		fi
	done
fi
if [ $SP -eq 4 ]; then
	get_connect
	export SETAPN=$NAPN
	BRK=1

	while [ $BRK -eq 1 ]; do
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "connect-fecm.gcom" "$CURRMODEM")
		chcklog "$OX"
		log " "
		log "FM150 Connect : $OX"
		log " "
		ERROR="ERROR"
		if `echo ${OX} | grep "${ERROR}" 1>/dev/null 2>&1`
		then
			$ROOTER/signal/status.sh $CURRMODEM "$MAN $MOD" "Failed to Connect : Retrying"
		else
			BRK=0
		fi
	done
fi
if [ $SP = 5 ]; then
	get_connect
	if [ -n "$NAPN" ]; then
		$ROOTER/common/lockchk.sh $CURRMODEM
		IPVAR="IP"
		ATCMDD="AT+CGDCONT=?"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
		if `echo ${OX} | grep "IPV4V6" 1>/dev/null 2>&1`; then
			IPVAR="IPV4V6"
		fi
		ATCMDD="AT+CGDCONT?"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
		CGDCONT=$(echo $OX | grep -o "1,[^,]\+,[^,]\+,[^,]\+,0,0,1")
		IPCG=$(echo $CGDCONT | cut -d, -f4)
		if [ "$CGDCONT" != "1,\"$IPVAR\",\"$NAPN\",$IPCG,0,0,1" ]; then
			ATCMDD="AT+CGDCONT=1,\"$IPVAR\",\"$NAPN\",,0,0,1"
			OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
		fi
	fi
	ATCMDD="AT+CNMI?"
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	if `echo $OX | grep -o "+CNMI: [0-3],2," >/dev/null 2>&1`; then
		ATCMDD="AT+CNMI=0,0,0,0,0"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	fi
	ATCMDD="AT+QINDCFG=\"smsincoming\""
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	if `echo $OX | grep -o ",1" >/dev/null 2>&1`; then
		ATCMDD="AT+QINDCFG=\"smsincoming\",0,1"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	fi
	ATCMDD="AT+QINDCFG=\"all\""
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	if `echo $OX | grep -o ",1" >/dev/null 2>&1`; then
		ATCMDD="AT+QINDCFG=\"all\",0,1"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	fi
	log "Quectel Unsolicited Responses Disabled"
	$ROOTER/luci/celltype.sh $CURRMODEM
	ATCMDD="AT+QINDCFG=\"all\",1"
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
fi

rm -f /tmp/usbwait

ifup wan$INTER
while `ifstatus wan$INTER | grep -q '"up": false\|"pending": true'`; do
	sleep 1
done
wan_ip=$(expr "`ifstatus wan$INTER | grep '"nexthop":'`" : '.*"nexthop": "\(.*\)"')
if [ $? -ne 0 ] ; then
	wan_ip=192.168.0.1
fi
uci set modem.modem$CURRMODEM.ip=$wan_ip
uci commit modem

$ROOTER/log/logger "HostlessModem #$CURRMODEM Connected with IP $wan_ip"

PROT=5

if [ $SP -gt 1 ]; then
	ln -s $ROOTER/signal/modemsignal.sh $ROOTER_LINK/getsignal$CURRMODEM
	$ROOTER_LINK/getsignal$CURRMODEM $CURRMODEM $PROT &
	if [ -e /etc/bandlock ]; then
		M1='AT+COPS=?'
		export TIMEOUT="120"
		#OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$M1")
		export TIMEOUT="5"
	fi
else
	VENDOR=$(uci get modem.modem$CURRMODEM.idV)
	case $VENDOR in
	"19d2" )
		TIMEOUT=3
		wget -O /tmp/connect.file http://$wan_ip/goform/goform_set_cmd_process?goformId=CONNECT_NETWORK &
		handle_timeout "$!"
		ln -s $ROOTER/signal/ztehostless.sh $ROOTER_LINK/getsignal$CURRMODEM
		$ROOTER_LINK/getsignal$CURRMODEM $CURRMODEM $PROT &
		;;
	"12d1" )
		log "Huawei Hostless"
		ln -s $ROOTER/signal/huaweihostless.sh $ROOTER_LINK/getsignal$CURRMODEM
		$ROOTER_LINK/getsignal$CURRMODEM $CURRMODEM $PROT &
		;;
	* )
		log "Other Hostless"
		ln -s $ROOTER/signal/otherhostless.sh $ROOTER_LINK/getsignal$CURRMODEM
		$ROOTER_LINK/getsignal$CURRMODEM $CURRMODEM $PROT &
		;;
esac
fi

ln -s $ROOTER/connect/conmon.sh $ROOTER_LINK/con_monitor$CURRMODEM
$ROOTER_LINK/con_monitor$CURRMODEM $CURRMODEM &
uci set modem.modem$CURRMODEM.connected=1
uci commit modem

if [ -e $ROOTER/timezone.sh ]; then
	TZ=$(uci -q get modem.modeminfo$CURRMODEM.tzone)
	if [ "$TZ" = "1" ]; then
		log "Set TimeZone"
		$ROOTER/timezone.sh &
	fi
fi

CLB=$(uci -q get modem.modeminfo$CURRMODEM.lb)
if [ -e /etc/config/mwan3 ]; then
	ENB=$(uci -q get mwan3.wan$INTER.enabled)
	if [ ! -z $ENB ]; then
		if [ $CLB = "1" ]; then
			uci set mwan3.wan$INTER.enabled=1
		else
			uci set mwan3.wan$INTER.enabled=0
		fi
		uci commit mwan3
		/usr/sbin/mwan3 restart
	fi
fi
