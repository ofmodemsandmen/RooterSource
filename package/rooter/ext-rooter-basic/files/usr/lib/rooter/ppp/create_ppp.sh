#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	modlog "Create Connection $CURRMODEM" "$@"
}

ifname1="ifname"
if [ -e /etc/newstyle ]; then
	ifname1="device"
fi

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
		if [ $DHCP = 1 ]; then
			uci set network.wan$INTER.peerdns=0
			uci set network.wan$INTER.dns="$bDNS"
		fi
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
		log "Using Provider assigned DNS"
		pdns=0
		rm -f /tmp/v[46]dns$INTER
	fi
}

save_variables() {
	echo 'MODSTART="'"$MODSTART"'"' > /tmp/variable.file
	echo 'WWAN="'"$WWAN"'"' >> /tmp/variable.file
	echo 'USBN="'"$USBN"'"' >> /tmp/variable.file
	echo 'ETHN="'"$ETHN"'"' >> /tmp/variable.file
	echo 'WDMN="'"$WDMN"'"' >> /tmp/variable.file
	echo 'BASEPORT="'"$BASEPORT"'"' >> /tmp/variable.file
}

get_connect() {
	NAPN=$(uci get modem.modeminfo$CURRMODEM.apn)
	NUSER=$(uci get modem.modeminfo$CURRMODEM.user)
	NPASS=$(uci get modem.modeminfo$CURRMODEM.passw)
	NAUTH=$(uci get modem.modeminfo$CURRMODEM.auth)
	PINC=$(uci get modem.modeminfo$CURRMODEM.pincode)

	uci set modem.modem$CURRMODEM.apn=$NAPN
	uci set modem.modem$CURRMODEM.user=$NUSER
	uci set modem.modem$CURRMODEM.pass=$NPASS
	uci set modem.modem$CURRMODEM.auth=$NAUTH
	uci set modem.modem$CURRMODEM.pin=$PINC
	uci commit modem
}

CURRMODEM=$1
source /tmp/variable.file

MAN=$(uci get modem.modem$CURRMODEM.manuf)
MOD=$(uci get modem.modem$CURRMODEM.model)
BASEP=$(uci get modem.modem$CURRMODEM.baseport)
$ROOTER/signal/status.sh $CURRMODEM "$MAN $MOD" "Connecting"
PROT=$(uci get modem.modem$CURRMODEM.proto)

DELAY=$(uci get modem.modem$CURRMODEM.delay)
if [ -z $DELAY ]; then
	DELAY=5
fi

idV=$(uci get modem.modem$CURRMODEM.idV)
idP=$(uci get modem.modem$CURRMODEM.idP)

cat /sys/kernel/debug/usb/devices > /tmp/cdma
lua $ROOTER/cdmafind.lua $idV $idP
retval=$?
rm -f /tmp/cdma
if [ $retval -eq 1 ]; then
	log "Found CDMA modem"
fi

case $PROT in
"10" )
	if [ $retval -eq 0 ]; then
		DP=0
		CP=2
	else
		DP=0
		CP=0
	fi
	;;
"11"|"12" )
	if [ $retval -eq 0 ]; then
		DP=3
		CP=2
	else
		DP=3
		CP=2
	fi
	;;
"13" )
	if [ $retval -eq 0 ]; then
		DP=4
		CP=3
	else
		DP=0
		CP=0
	fi
	;;
"14" )
	if [ $retval -eq 0 ]; then
		DP=3
		CP=2
	else
		DP=0
		CP=0
	fi
	;;
"15" )
	if [ $retval -eq 0 ]; then
		DP=1
		CP=2
	else
		DP=0
		CP=0
	fi
	;;
"16" )
	if [ $retval -eq 0 ]; then
		DP=2
		CP=0
		ln -s /dev/ttyACM$CP /dev/ttyUSB$CP
		ln -s /dev/ttyACM$DP /dev/ttyUSB$DP
	else
		DP=0
		CP=0
	fi
	;;
esac

$ROOTER/common/modemchk.lua "$idV" "$idP" "$DP" "$CP"
source /tmp/parmpass

CPORT=`expr $CPORT + $BASEP`
DPORT=`expr $DPORT + $BASEP`
uci set modem.modem$CURRMODEM.commport=$CPORT
uci set modem.modem$CURRMODEM.dataport=$DPORT
uci set modem.modem$CURRMODEM.service=$retval
uci commit modem

if [ -e $ROOTER/modem-led.sh ]; then
	$ROOTER/modem-led.sh $CURRMODEM 2
fi

log "PPP Comm Port : /dev/ttyUSB$CPORT"
log "PPP Data Port : /dev/ttyUSB$DPORT"

if [ -e /usr/lib/rooter/connect/mhi2usb.sh ]; then
	/usr/lib/rooter/connect/mhi2usb.sh $CURRMODEM
fi

if [ -e /tmp/mhiusb ]; then
	exit 0
fi

if [ -z "$idV" ]; then
	idV=$(uci -q get modem.modem$CURRMODEM.idV)
fi
QUECTEL=false
if [ "$idV" = "2c7c" ]; then
	QUECTEL=true
elif [ "$idV" = "05c6" ]; then
	QUELST="9090,9003,9215"
	if [[ $(echo "$QUELST" | grep -o "$idP") ]]; then
		QUECTEL=true
	fi
fi

if [ -e /etc/config/wizard ]; then
	wiz=$(uci -q get wizard.basic.wizard)
	if [ "$wiz" = "1" ]; then
		uci set wizard.basic.detect="2"
		uci commit wizard
		exit 0
	fi
	uci set wizard.basic.detect="1"
	uci commit wizard
fi

if [ -e $ROOTER/connect/preconnect.sh ]; then
	if [ "$RECON" != "2" ]; then
		$ROOTER/connect/preconnect.sh $CURRMODEM
	fi
fi

if $QUECTEL; then
	if [ "$RECON" != "2" ]; then
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
	fi
	$ROOTER/connect/bandmask $CURRMODEM 1
	clck=$(uci -q get custom.bandlock.cenable$CURRMODEM)
	if [ $clck = "1" ]; then
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
		if [ $ear1 != "0" -a $pc1 != "0" ]; then
			earcnt=$earcnt","$ear1","$pc1
			let cnt=cnt+1
		fi
		if [ $ear2 != "0" -a $pc2 != "0" ]; then
			earcnt=$earcnt","$ear2","$pc2
			let cnt=cnt+1
		fi
		if [ $ear3 != "0" -a $pc3 != "0" ]; then
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
fi


$ROOTER/common/gettype.sh $CURRMODEM
$ROOTER/connect/get_profile.sh $CURRMODEM
get_connect
if [ -e $ROOTER/simlock.sh ]; then
	$ROOTER/simlock.sh $CURRMODEM
fi

if [ -e /tmp/simpin$CURRMODEM ]; then
	log " SIM Error"
	if [ -e $ROOTER/simerr.sh ]; then
		$ROOTER/simerr.sh $CURRMODEM
	fi
	if [ -e /etc/config/wizard]; then
		uci set wizard.basic.detect="2"
		uci commit wizard
	fi
	exit 0
fi

if [ -e /usr/lib/gps/gps.sh ]; then
	/usr/lib/gps/gps.sh $CURRMODEM &
fi

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
uci delete network.wan$INTER
uci set network.wan$INTER=interface
uci set network.wan$INTER.${ifname1}=3x-wan$INTER
uci set network.wan$INTER.proto=3x
if [ $retval -eq 0 ]; then
	uci set network.wan$INTER.service=umts
else
	uci set network.wan$INTER.service=cdma
fi
uci set network.wan$INTER.keepalive=10
uci set network.wan$INTER.device=/dev/ttyUSB$DPORT
uci set network.wan$INTER.apn=$NAPN
uci set network.wan$INTER.username=$NUSER
uci set network.wan$INTER.auth=$NAUTH
uci set network.wan$INTER.password=$NPASS
uci set network.wan$INTER.pincode=$PINC
uci set network.wan$INTER.metric=$CURRMODEM"0"
uci set network.wan$INTER.currmodem=$CURRMODEM
uci set network.wan$INTER.pppd_options="debug noipdefault"
set_dns
uci commit network

if [ $retval -eq 0 ]; then
	case $idV in
	"1199"|"0f3d"|"413c"|"2c7c"|"05c6" )
		$ROOTER/luci/celltype.sh $CURRMODEM
		;;
	esac
	$ROOTER/common/lockchk.sh $CURRMODEM
	$ROOTER/sms/check_sms.sh $CURRMODEM &
fi

rm -f /tmp/usbwait
log "Start Connection"
ifup wan$INTER
