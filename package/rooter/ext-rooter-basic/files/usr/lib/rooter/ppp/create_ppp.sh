#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	logger -t "Create Connection" "$@"
}

set_dns() {
	local DNS1=$(uci get modem.modeminfo$CURRMODEM.dns1)
	local DNS2=$(uci get modem.modeminfo$CURRMODEM.dns2)
	if [ -z $DNS1 ]; then
		if [ -z $DNS2 ]; then
			return
		else
			uci set network.wan$INTER.peerdns=0
			uci set network.wan$INTER.dns=$DNS2
		fi
	else
		uci set network.wan$INTER.peerdns=0
		if [ -z $DNS2 ]; then
			uci set network.wan$INTER.dns="$DNS1"
		else
			uci set network.wan$INTER.dns="$DNS2 $DNS1"
		fi
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
		DP=2
		CP=1
	else
		DP=0
		CP=0
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

$ROOTER/common/gettype.sh $CURRMODEM
$ROOTER/connect/get_profile.sh $CURRMODEM
get_connect

INTER=$(uci get modem.modeminfo$CURRMODEM.inter)
if [ -z $INTER ]; then
	INTER=$CURRMODEM
else
	if [ $INTER = 0 ]; then
		INTER=$CURRMODEM
	fi
fi
log "Profile for Modem$CURRMODEM sets interface to WAN$INTER"
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
			log "Switched Modem$CURRMODEM to WAN$INTER as Modem$OTHER is using WAN$OINTER"
		fi
	fi
fi
uci set modem.modem$CURRMODEM.inter=$INTER
uci commit modem
log "Modem$CURRMODEM is using WAN$INTER"
uci delete network.wan$INTER
uci set network.wan$INTER=interface
uci set network.wan$INTER.ifname=3x-wan$INTER
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

log "PPP Comm Port : /dev/ttyUSB$CPORT"
log "PPP Data Port : /dev/ttyUSB$DPORT"

if [ $retval -eq 0 ]; then
	case $idV in
	"1199"|"0f3d"|"413c"|"2c7c"|"05c6" )
		$ROOTER/luci/celltype.sh $CURRMODEM
		;;
	esac
	$ROOTER/common/lockchk.sh $CURRMODEM
	$ROOTER/sms/check_sms.sh $CURRMODEM &
fi

if [ -e $ROOTER/modem-led.sh ]; then
	$ROOTER/modem-led.sh $CURRMODEM 2
fi

rm -f /tmp/usbwait
ifup wan$INTER
