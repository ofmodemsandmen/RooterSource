#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	modlog "Create Hostless Connection $CURRMODEM" "$@"
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

check_apn() {
	IPVAR="IP"
	local COMMPORT="/dev/ttyUSB"$CPORT
	if [ -e /etc/nocops ]; then
		echo "0" > /tmp/block
	fi
	ATCMDD="AT+CGDCONT=?"
	OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	[ "$PDPT" = "0" ] && PDPT=""
	for PDP in "$PDPT" IPV4V6; do
		if [[ "$(echo $OX | grep -o "$PDP")" ]]; then
			IPVAR="$PDP"
			break
		fi
	done

	uci set modem.modem$CURRMODEM.pdptype=$IPVAR
	uci commit modem

	log "PDP Type selected in the Connection Profile: \"$PDPT\", active: \"$IPVAR\""

	if [ "$idV" = "12d1" ]; then
		CFUNOFF="0"
	else
		CFUNOFF="4"
	fi
	ATCMDD="AT+CGDCONT?;+CFUN?"
	OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	CGDCONT2=$(echo $OX | grep "+CGDCONT: 2,")
	if [ -z "$CGDCONT2" ]; then
		ATCMDD="AT+CGDCONT=2,\"$IPVAR\",\"ims\""
		OXy=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	fi
	CGDCONT=$(echo $OX | grep -o "$CID,[^,]\+,[^,]\+,[^,]\+,0,0,1")
	IPCG=$(echo $CGDCONT | cut -d, -f4)
	if [ "$CGDCONT" == "$CID,\"$IPVAR\",\"$NAPN\",$IPCG,0,0,1" ]; then
		if [ -z "$(echo $OX | grep -o "+CFUN: 1")" ]; then
			OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "AT+CFUN=1")
			log "$OX"
		fi
	else
		ATCMDD="AT+CGDCONT=$CID,\"$IPVAR\",\"$NAPN\",,0,0,1"
		OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
		OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "AT+CFUN=$CFUNOFF")
		OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "AT+CFUN=1")
		sleep 5
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
		pdns=0
		for DNSV in $(echo "$aDNS"); do
			if [ "$DNSV" != "0:0:0:0:0:0:0:0" ] && [ -z "$(echo "$bDNS" | grep -o "$DNSV")" ]; then
				if [ ! -z "$(echo "$DNSV" | grep -o ":")" ]; then
					bDNS="$bDNS $DNSV"
					pdns=1
				fi
			fi
			if [ "$DNSV" != "0.0.0.0" ] && [ -z "$(echo "$bDNS" | grep -o "$DNSV")" ]; then
				[ -z "$(echo "$DNSV" | grep -o ".")" ] && continue
				bDNS="$bDNS $DNSV"
				pdns=1
			fi
		done
		if [ "$pdns" = "1" ]; then
			log "Using DNS settings from the Connection Profile $bDNS"
			bDNS=$(echo $bDNS)
			uci set network.wan$INTER.peerdns=0
			uci set network.wan$INTER.dns="$bDNS"
		else
			log "Using Hostless Modem as a DNS relay"
		fi
	else
		log "Using Hostless Modem as a DNS relay"
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
	NAPN2=$(uci -q get modem.modeminfo$CURRMODEM.apn2)
	NAPN3=$(uci -q get modem.modeminfo$CURRMODEM.apn3)
	NUSER=$(uci -q get modem.modeminfo$CURRMODEM.user)
	NPASS=$(uci -q get modem.modeminfo$CURRMODEM.passw)
	NAUTH=$(uci -q get modem.modeminfo$CURRMODEM.auth)
	PDPT=$(uci -q get modem.modeminfo$CURRMODEM.pdptype)
	uci set modem.modem$CURRMODEM.apn="$NAPN"
	uci set modem.modem$CURRMODEM.apn2=$NAPN2
	uci set modem.modem$CURRMODEM.apn3=$NAPN3
	uci set modem.modem$CURRMODEM.user=$NUSER
	uci set modem.modem$CURRMODEM.passw=$NPASS
	uci set modem.modem$CURRMODEM.auth=$NAUTH
	uci set modem.modem$CURRMODEM.pin=$PINC
	uci commit modem
}

get_tty_fix() {
# $1 is fixed ttyUSB or ttyACM port number
	local POS
	POS=`expr 1 + $1`
	CPORT=$(echo "$TTYDEVS" | cut -d' ' -f"$POS" | grep -o "[[:digit:]]\+")
}

get_ip() {
	ATCMDD="AT+CGPIAF=1,1,1,0;+CGPADDR"
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	OX=$(echo "$OX" | grep "^+CGPADDR: $CID,")
	first=$(echo "$OX" | cut -d, -f2 | tr -d \")
	is6=$(echo "$first" | grep ":")
	if [ ! -z "$is6" ]; then
		ip4=""
		ip6=$first
	else
		ip6=""
		ip4=$first
		sec=$(echo "$OX" | cut -d, -f3 | tr -d \")
		is6=$(echo "$sec" | grep ":")
		if [ ! -z "$is6" ]; then
			ip6=$sec
		fi
	fi
	log "IP address(es) obtained: $ip4 $ip6"
}

check_ip() {
	if [[ $(echo "$ip6" | grep -o "^[23]") ]]; then
	# Global unicast IP acquired
		v6cap=1
	elif [[ $(echo "$ip6" | grep -o "^[0-9a-fA-F]\{1,4\}:") ]]; then
	# non-routable address
		v6cap=2
	else
		v6cap=0
	fi

	if [ -n "$ip6" -a -z "$ip4" ]; then
		log "Running IPv6-only mode"
		nat46=1
	fi
}

addv6() {
	. /lib/functions.sh
	. /lib/netifd/netifd-proto.sh
	log "Adding IPv6 dynamic interface"

	#	config interface 'wan1_6'
	uci set network.wan$INTER"_6"._orig_ifname="@wan$INTER"
	uci set network.wan$INTER"_6"._orig_bridge='false'
	uci set network.wan$INTER"_6".proto='dhcpv6'
	uci set network.wan$INTER"_6".$ifname1="@wan$INTER"
	uci set network.wan$INTER"_6".reqaddress='try'
	uci set network.wan$INTER"_6".reqprefix='auto'
	TINTER=$INTER
	INTER=$INTER"_6"
	set_dns
	INTER=$TINTER
	uci commit network
	ifup wan$INTER"_6"
}

fcc_unlock() {
	VENDOR_ID_HASH="3df8c719"
	ATCMDD="at+gtfcclockgen"
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	CHALLENGE=$(echo "$OX" | grep -o '0x[0-9a-fA-F]\+' | awk '{print $1}')
	 if [ -n "$CHALLENGE" ]; then
        log "Got challenge from modem: $CHALLENGE"
        HEX_CHALLENGE=$(printf "%08x" "$CHALLENGE")
        COMBINED_CHALLENGE="${HEX_CHALLENGE}$(printf "%.8s" "${VENDOR_ID_HASH}")"
        RESPONSE_HASH=$(echo "$COMBINED_CHALLENGE" | xxd -r -p | sha256sum | cut -d ' ' -f 1)
        TRUNCATED_RESPONSE=$(printf "%.8s" "$RESPONSE_HASH")
        RESPONSE=$(printf "%d" "0x$TRUNCATED_RESPONSE")

        log "Sending response to modem: $RESPONSE"
        #UNLOCK_RESPONSE=$(at_command "at+gtfcclockver=$RESPONSE")
		ATCMDD="at+gtfcclockver=$RESPONSE"
		UNLOCK_RESPONSE=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
		succ=$(echo "$UNLOCK_RESPONSE" | grep "+GTFCCLOCKVER: 1")
        if [ ! -z "$succ" ]; then
			log "FCC unlock succeeded"
            return
         else
            log "Unlock failed. Got response: $UNLOCK_RESPONSE"
        fi
    else
        log "Failed to obtain FCC challenge. Got: ${RAW_CHALLENGE}"
    fi

}

CURRMODEM=$1

MAN=$(uci -q get modem.modem$CURRMODEM.manuf)
MOD=$(uci -q get modem.modem$CURRMODEM.model)
$ROOTER/signal/status.sh $CURRMODEM "$MAN $MOD" "Connecting"
$ROOTER/log/logger "Attempting to Connect Modem #$CURRMODEM ($MAN $MOD)"

BASEP=$(uci -q get modem.modem$CURRMODEM.baseport)
idV=$(uci -q get modem.modem$CURRMODEM.idV)
idP=$(uci -q get modem.modem$CURRMODEM.idP)
log " "
log "Hostless ID $idV:$idP"
log " "

MATCH="$(uci -q get modem.modem$CURRMODEM.maxcontrol | cut -d/ -f3- | xargs dirname)"
OX=$(for a in /sys/class/tty/*; do readlink $a; done | grep "$MATCH" | tr '\n' ' ' | xargs -r -n1 basename)
TTYDEVS=$(echo "$OX" | grep -o ttyUSB)
if [ $? -ne 0 ]; then
	TTYDEVS=$(echo "$OX" | grep -o ttyACM)
	[ $? -eq 0 ] && ACM=1
fi
echo "$OX" > /tmp/ttyp
$ROOTER/connect/getports.lua
TTYDEVS=$(cat /tmp/ttyp | tr '\n' ' ')
TTYDEVS=$(echo $TTYDEVS)
TTYDEVS=$(echo $TTYDEVS)
if [ -n "$TTYDEVS" ]; then
	log "Modem $CURRMODEM is a parent of $TTYDEVS"
else
	log "No ECM Comm Port"
fi

if [ $idV = 1546 -a $idP = 1146 ]; then
	SP=1
elif [ $idV = 19d2 -a $idP = 1476 ]; then
	SP=2
elif [ $idV = 1410 -a $idP = 9022 ]; then
	SP=3
elif [ $idV = 1410 -a $idP = 9032 ]; then
	SP=3
elif [ $idV = 2cb7 -o $idV = 1508 ]; then
	sleep 5
	log "Fibocom ECM"
	SP=4
elif [ $idV = 2c7c ]; then
	SP=5
elif [ $idV = 12d1 -a $idP = 15c1 ]; then
	SP=6
elif [ $idV = 2cd2 ]; then
	log "MikroTik R11e ECM"
	SP=7
elif [ $idV = 0e8d -a $idP = 7127  ]; then
	log "RM350 ECM"
	SP=8
elif [ $idV = 0e8d -a $idP = 7126  ]; then
	log "RM350 ECM"
	SP=9
elif [ $idV = 0e8d -a $idP = 2028  ]; then
	log "FG370 ECM"
	SP=9
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
		[ $idP = 6026 ] && PORTN=1 || PORTN=2
	elif [ $SP -eq 6 ]; then
		PORTN=2
	elif [ $SP -eq 7 ]; then
		PORTN=0
	elif [ $SP -eq 8 ]; then
		PORTN=3
	elif [ $SP -eq 9 ]; then
		PORTN=1
	else
		PORTN=1
	fi
	get_tty_fix $PORTN
	lua $ROOTER/common/modemchk.lua "$idV" "$idP" "$CPORT" "$CPORT"
	source /tmp/parmpass

	if [ "$ACM" = 1 ]; then
		ACMPORT=$CPORT
		CPORT="7$ACMPORT"
		ln -fs /dev/ttyACM$ACMPORT /dev/ttyUSB$CPORT
	fi

	log "Modem $CURRMODEM ECM Comm Port : /dev/ttyUSB$CPORT"
	uci set modem.modem$CURRMODEM.commport=$CPORT
	uci commit modem

	$ROOTER/sms/check_sms.sh $CURRMODEM &

	if [ -e $ROOTER/connect/preconnect.sh ]; then
		$ROOTER/connect/preconnect.sh $CURRMODEM
	fi

	if [ $SP = 5 ]; then
		clck=$(uci -q get custom.bandlock.cenable$CURRMODEM)
		if [ "$clck" = "1" ]; then
			ear=$(uci -q get custom.bandlock.earfcn$CURRMODEM)
			pc=$(uci -q get custom.bandlock.pci$CURRMODEM)
			ear1=$(uci -q get custom.bandlock.earfcn1$CURRMODEM)
			pc1=$(uci -q get custom.bandlock.pci1$CURRMODEM)
			ear2=$(uci -q get custom.bandlock.earfcn2$CURRMODEM)
			pc2=$(uci -q get custom.bandlock.pci2$CURRMODEM)
			ear3=$(uci -q get custom.bandlock.earfcn3$CURRMODEM)
			pc3=$(uci -q get custom.bandlock.pci3$CURRMODEM)
			cnt=1
			earcnt=$ear","$pc
			if [ "$ear1" != "0" -a $pc1 != "0" ]; then
				earcnt=$earcnt","$ear1","$pc1
				let cnt=cnt+1
			fi
			if [ "$ear2" != "0" -a $pc2 != "0" ]; then
				earcnt=$earcnt","$ear2","$pc2
				let cnt=cnt+1
			fi
			if [ "$ear3" != "0" -a $pc3 != "0" ]; then
				earcnt=$earcnt","$ear3","$pc3
				let cnt=cnt+1
			fi
			earcnt=$cnt","$earcnt
			ATCMDD="at+qnwlock=\"common/4g\""
			OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
			log "$OX"
			if `echo $OX | grep "ERROR" 1>/dev/null 2>&1`
			then
				ATCMDD="at+qnwlock=\"common/lte\",2,$ear,$pc"
			else
				ATCMDD=$ATCMDD","$earcnt
			fi
			OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
			log "Cell Lock $OX"
			sleep 10
		fi
		$ROOTER/connect/bandmask $CURRMODEM 1
		uci commit modem
		if [ -e /usr/lib/rooter/connect/mhi2usb.sh ]; then
			/usr/lib/rooter/connect/mhi2usb.sh $CURRMODEM
		fi
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
	if [ $SP = 8 -o  $SP = 9 ]; then
		log "FM350 Unlock Command"
		fcc_unlock
		$ROOTER/connect/bandmask $CURRMODEM 2
		uci commit modem
	fi
	if [ -e $ROOTER/simlock.sh ]; then
		$ROOTER/simlock.sh $CURRMODEM
	fi
	$ROOTER/common/gettype.sh $CURRMODEM
fi
	
if [ -e $ROOTER/modem-led.sh ]; then
	$ROOTER/modem-led.sh $CURRMODEM 2
fi

$ROOTER/connect/get_profile.sh $CURRMODEM
detect=$(uci -q get modem.modeminfo$CURRMODEM.detect)
if [ "$detect" = "1" ]; then
	log "Stopped after detection"
	exit 0
fi
if [ $SP -gt 0 ]; then
	if [ -e $ROOTER/simlock.sh ]; then
		$ROOTER/simlock.sh $CURRMODEM
	fi

	if [ -e /tmp/simpin$CURRMODEM ]; then
		log " SIM Error"
		if [ -e $ROOTER/simerr.sh ]; then
			$ROOTER/simerr.sh $CURRMODEM
		fi
		if [ -e $ROOTER/connect/simreboot.sh ]; then
			$ROOTER/connect/simreboot.sh
		fi
		exit 0
	fi

	if [ -e /usr/lib/gps/gps.sh ]; then
		/usr/lib/gps/gps.sh $CURRMODEM &
	fi
fi

if [ -e $ROOTER/connect/chkconn.sh ]; then
	$ROOTER/connect/chkconn.sh $CURRMODEM &
fi

INTER=$(uci -q get modem.modeminfo$CURRMODEM.inter)
if [ -z "$INTER" ]; then
	INTER=$CURRMODEM
else
	if [ "$INTER" = 0 ]; then
		INTER=$CURRMODEM
	fi
fi
log "Profile for Modem $CURRMODEM sets interface to WAN$INTER"
OTHER=1
if [ $CURRMODEM = 1 ]; then
	OTHER=2
fi
EMPTY=$(uci -q get modem.modem$OTHER.empty)
if [ "$EMPTY" = 0 ]; then
	OINTER=$(uci -q get modem.modem$OTHER.inter)
	if [ ! -z "$OINTER" ]; then
		if [ $INTER = $OINTER ]; then
			INTER=1
			if [ "$OINTER" = 1 ]; then
				INTER=2
			fi
			log "Switched Modem $CURRMODEM to WAN$INTER as Modem $OTHER is using WAN$OINTER"
		fi
	fi
fi
uci set modem.modem$CURRMODEM.inter=$INTER
uci commit modem
log "Modem $CURRMODEM is using WAN$INTER"

CID=$(uci -q get modem.modeminfo$CURRMODEM.context)
[ -z "$CID" ] && CID=1

log "Checking Network Interface"
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

hostless=$(uci -q get modem.modeminfo$CURRMODEM.hostless)
$ROOTER/connect/handlettl.sh $CURRMODEM "$hostless" &

autoapn=$(uci -q get profile.disable.autoapn)
imsi=$(uci -q get modem.modem$CURRMODEM.imsi)
mcc6=${imsi:0:6}
mcc5=${imsi:0:5}
get_connect
apndata=""
if [ -e /usr/lib/rooter/connect/apndata.sh ]; then
	/usr/lib/rooter/connect/apndata.sh $CURRMODEM
	if [ -e /tmp/apndata ]; then
		apndata=$(cat /tmp/apndata)" "
	fi
fi

apd=0
if [ -e /usr/lib/autoapn/apn.data ]; then
	apd=1
fi
pdptype="ipv4v6"
IPVAR=$(uci -q get modem.modeminfo$CURRMODEM.pdptype)
case "$IPVAR" in
	"IP" )
		pdptype="ipv4"
	;;
	"IPV6" )
		pdptype="ipv6"
	;;
	"IPV4V6" )
		pdptype="ipv4v6"
	;;
esac
if [ "$autoapn" = "1" -a $apd -eq 1 ]; then
	isplist=$(grep -F "$mcc6" '/usr/lib/autoapn/apn.data')
	if [ -z "$isplist" ]; then
		isplist=$(grep -F "$mcc5" '/usr/lib/autoapn/apn.data')
		if [ -z "$isplist" ]; then
			isplist="000000,$NAPN,Default,$NPASS,$CID,$NUSER,$NAUTH,$pdptype"
			if [ ! -z "$NAPN2" ]; then
				isplist=$isplist" 000000,$NAPN2,Default,$NPASS,$CID,$NUSER,$NAUTH,$pdptype"
			fi
			if [ ! -z "$NAPN3" ]; then
				isplist=$isplist" 000000,$NAPN3,Default,$NPASS,$CID,$NUSER,$NAUTH,$pdptype"
			fi
		fi
	fi
else
	if [ -z "$apndata" ]; then
		isplist=$apndata"000000,$NAPN,Default,$NPASS,$CID,$NUSER,$NAUTH,$pdptype"
		if [ ! -z "$NAPN2" ]; then
			isplist=$isplist" 000000,$NAPN2,Default,$NPASS,$CID,$NUSER,$NAUTH,$pdptype"
		fi
		if [ ! -z "$NAPN3" ]; then
			isplist=$isplist" 000000,$NAPN3,Default,$NPASS,$CID,$NUSER,$NAUTH,$pdptype"
		fi
	else
		isplist=$apndata
	fi
fi
log "$isplist"
uci set modem.modeminfo$CURRMODEM.isplist="$isplist"
uci commit modem
rm -f /tmp/usbwait
for isp in $isplist
do
	NAPN=$(echo $isp | cut -d, -f2)
	NPASS=$(echo $isp | cut -d, -f4)
	CID=$(echo $isp | cut -d, -f5)
	NUSER=$(echo $isp | cut -d, -f6)
	NAUTH=$(echo $isp | cut -d, -f7)
	if [ "$NPASS" = "nil" ]; then
		NPASS="NIL"
	fi
	if [ "$NUSER" = "nil" ]; then
		NUSER="NIL"
	fi
	if [ "$NAUTH" = "nil" ]; then
		NAUTH="0"
	fi
	export SETAPN=$NAPN
	export SETUSER=$NUSER
	export SETPASS=$NPASS
	export SETAUTH=$NAUTH
	export PINCODE=$PINC

	uci set modem.modem$CURRMODEM.apn=$NAPN
	uci set modem.modem$CURRMODEM.user=$NUSER
	uci set modem.modem$CURRMODEM.passw=$NPASS
	uci set modem.modem$CURRMODEM.auth=$NAUTH
	uci set modem.modem$CURRMODEM.pin=$PINC
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

	if [ $SP -eq 4 ]; then
		#get_connect
		export SETAPN=$NAPN
		BRK=1

		while [ $BRK -eq 1 ]; do
			OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "connect-fecm.gcom" "$CURRMODEM")
			chcklog "$OX"
			log " "
			log "Fibocom Connect : $OX"
			log " "
			ERROR="ERROR"
			if `echo ${OX} | grep "${ERROR}" 1>/dev/null 2>&1`
			then
				$ROOTER/signal/status.sh $CURRMODEM "$MAN $MOD" "Failed to Connect : Retrying"
			else
				BRK=0
				get_ip
			fi
		done
	fi
		
	if [ $SP = 8 -o  $SP = 9 ]; then
		log "FM350 Connection Command"
		#fcc_unlock
		#$ROOTER/connect/bandmask $CURRMODEM 2
		uci commit modem
		#get_connect
		export SETAPN=$NAPN
		BRK=1
		
			ATCMDD="AT+CGPIAF=1,0,0,0;+CGDCONT=1"
			OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
			log "$OX"
				
			ATCMDD='AT+CGDCONT=1,"IP","'$NAPN'",,0,0,0,0,0,0,0'
			OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
			chcklog "$OX"
			log " "
			log "Fibocom Connect : $OX"
			log " "
			ERROR="ERRORX"
			if `echo ${OX} | grep "${ERROR}" 1>/dev/null 2>&1`
			then
				$ROOTER/signal/status.sh $CURRMODEM "$MAN $MOD" "Failed to Connect : Retrying"
				log "Failed to Connect"
			else
				BRK=0
				ATCMDD="AT+CGACT=0"
					OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
					log "$OX"
				ATCMDD="AT+CGPADDR=0"
				OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
				log "$OX"

				cntr=0
				while [ true ]; do
					ATCMDD="AT+CGACT=1,1"
					OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
					log "$OX"
					cgev=$(echo "$OX" | grep "+CGEV")
					if [ ! -z "$cgev" ]; then
						break;
					fi
					let cntr=$cntr+1
					if [ "$cntr" -gt 1 ]; then
						break
					fi
					sleep 5
				done
				
				ATCMDD="AT+CGPADDR=1"
				OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
				log "$OX"
				OX=$(echo "$OX" | grep "^+CGPADDR: 1," | cut -d'"' -f2)
				ip4=$(echo $OX | cut -d, -f1 | grep "\.")
				ip6=$(echo $OX | cut -d, -f2 | grep ":")
				log "IP address(es) obtained: $ip4 $ip6"
				if [ -z "$ip4" ]; then
					BRK=1
					log "No IP Address"
				else
					check_ip
								
					gtw=$(echo "$ip4" | cut -d. -f1)"."$(echo "$ip4" | cut -d. -f2)"."$(echo "$ip4" | cut -d. -f3)".1"
					uci set network.wan$INTER.proto='static'
					uci set network.wan$INTER.ipaddr="$ip4"
					uci set network.wan$INTER.netmask='255.255.255.0'
					uci set network.wan$INTER.gateway="$gtw"
					uci set network.wan$INTER.dns="1.1.1.1"
					uci set network.wan$INTER.peerdns=0
					set_dns
					uci commit network
					ifup wan$INTER
					rm -f /tmp/usbwait
				fi
			fi
	fi

	if [ $SP = 5 ]; then
		#get_connect
		if [ -n "$NAPN" ]; then
			$ROOTER/common/lockchk.sh $CURRMODEM
			if [ $idP = 6026 ]; then
				IPN=1
				case "$PDPT" in
				"IPV6" )
					IPN=2
					;;
				"IPV4V6" )
					IPN=3
					;;
				esac
				ATCMDD="AT+QICSGP=$CID,$IPN,\"$NAPN\""
				OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
				ATCMDD="AT+QNETDEVCTL=2,$CID,1"
				OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
			else
				check_apn
				log "Using $NAPN"
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
		BRK=0
		get_ip
		if [ -z "$ip4" -o "$ip4" = "0.0.0.0" ]; then
			if [ -z "$ip6" -o "$ip6" = "0000:0000:0000:0000:0000:0000:0000:0000" ]; then
				ATCMDD="AT+QMAP=\"WWAN\""
				OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
				echo "$OX" > /tmp/wwanox
				while IFS= read -r line; do
					qm=$(echo "$line" | grep "IPV4")
					if [ ! -z "$qm" ]; then
						ip4=$(echo $line | cut -d, -f5 | tr -d '"' )
					fi
					qm=$(echo "$line" | grep "IPV6")
					if [ ! -z "$qm" ]; then
						ip6=$(echo $line | cut -d, -f5 | tr -d '"' )
					fi
				done < /tmp/wwanox
				rm -f /tmp/wwanox
				log "WWAN IP : $ip4 $ip6"
				if [ -z "$ip4" -o "$ip4" = "0.0.0.0" ]; then
					if [ -z "$ip6" -o "$ip6" = "0000:0000:0000:0000:0000:0000:0000:0000" -o "$ip6" = "0:0:0:0:0:0:0:0" ]; then
						BRK=1
						log "No IP Address"
					fi
				fi
			fi
		fi
		if [ "$BRK" = 0 ]; then
			if [ -n "$ip6" ]; then
				check_ip
				if [ "$v6cap" -gt 0 ]; then
					ip6=$ip6
					addv6
				fi
			fi
		fi
	fi

	if [ $SP -eq 6 ]; then
		#get_connect
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

	if [ $SP -eq 7 ]; then
		#get_connect
		export SETAPN=$NAPN
		BRK=1

		if [ -n "$NAPN" ]; then
			check_apn
		fi

		while [ $BRK -eq 1 ]; do
			ATCMDD="AT\$ECMCALL=1"
			OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
			chcklog "$OX"
			ERROR="ERROR"
			if `echo ${OX} | grep "${ERROR}" 1>/dev/null 2>&1`
			then
				$ROOTER/signal/status.sh $CURRMODEM "$MAN $MOD" "Failed to Connect : Retrying"
			else
				BRK=0
				get_ip
				if [ -n "$ip6" ]; then
					check_ip
					if [ "$v6cap" -gt 0 ]; then
						BRK=0
						#addv6
					fi
				fi
			fi
		done
	fi

	if [ $BRK = 0 ]; then
		break
	fi
done

if [ $BRK = 1 ]; then
	log "Did not connect"
	exit 0
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

if [ -e $ROOTER/modem-led.sh ]; then
	$ROOTER/modem-led.sh $CURRMODEM 3
fi
		
$ROOTER/log/logger "HostlessModem #$CURRMODEM Connected with IP $wan_ip"

PROT=5

if [ $SP -gt 1 ]; then
	ln -s $ROOTER/signal/modemsignal.sh $ROOTER_LINK/getsignal$CURRMODEM
	$ROOTER_LINK/getsignal$CURRMODEM $CURRMODEM $PROT &
else
	VENDOR=$(uci -q get modem.modem$CURRMODEM.idV)
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

if [ $SP -gt 0 ]; then
	if [ -e $ROOTER/connect/postconnect.sh ]; then
		$ROOTER/connect/postconnect.sh $CURRMODEM
	fi
	ATCMDD=$(uci -q get modem.modeminfo$CURRMODEM.atc)
	if [ -n "$ATCMDD" ]; then
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
		OX=$($ROOTER/common/processat.sh "$OX")
		ERROR="ERROR"
		if `echo $OX | grep "$ERROR" 1>/dev/null 2>&1`
		then
			log "Error sending custom AT command: $ATCMDD with result: $OX"
		else
			log "Sent custom AT command: $ATCMDD with result: $OX"
		fi
	fi

	if [ -e $ROOTER/timezone.sh ]; then
		TZ=$(uci -q get modem.modeminfo$CURRMODEM.tzone)
		if [ "$TZ" = "1" ]; then
			log "Set TimeZone"
			$ROOTER/timezone.sh &
		fi
	fi
fi

#CLB=$(uci -q get modem.modeminfo$CURRMODEM.lb)
CLB=1
if [ -e /etc/config/mwan3 ]; then
	ENB=$(uci -q get mwan3.wan$INTER.enabled)
	if [ ! -z "$ENB" ]; then
		if [ "$CLB" = "1" ]; then
			uci set mwan3.wan$INTER.enabled=1
		else
			uci set mwan3.wan$INTER.enabled=0
		fi
		uci commit mwan3
		/usr/sbin/mwan3 restart
	fi
fi
