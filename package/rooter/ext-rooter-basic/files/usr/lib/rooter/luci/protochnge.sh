#!/bin/sh

ROOTER=/usr/lib/rooter

NEWMOD=$1

 log() {
	logger -t "ProtoChange" "$@"
 }
 
 chksierra() {
	SIERRAID=0
	if [ $idV = 1199 ]; then
		case $idP in
			"68aa"|"68a2"|"68a3"|"68a9"|"68b0"|"68b1" )
				SIERRAID=1
			;;
			"68c0"|"9040"|"9041"|"9051"|"9054"|"9056"|"90d3" )
				SIERRAID=1
			;;
			"9070"|"907b"|"9071"|"9079"|"901c"|"9091"|"901f"|"90b1" )
				SIERRAID=1
			;;
		esac
	elif [ $idV = 114f -a $idP = 68a2 ]; then
		SIERRAID=1
	elif [ $idV = 413c -a $idP = 81a8 ]; then
		SIERRAID=1
	elif [ $idV = 413c -a $idP = 81b6 ]; then
		SIERRAID=1
	fi
}

chkquectel() {
	QUECTEL=false
	if [ "$idV" = "2c7c" ]; then
		QUECTEL=true
	elif [ "$idV" = "05c6" ]; then
		QUELST="9090,9003,9215"
		if [[ $(echo "$QUELST" | grep -o "$idP") ]]; then
			QUECTEL=true
		fi
	fi
}

log "Protocol Change to $NEWMOD"

CURRMODEM=$(uci get modem.general.modemnum)
CPORT=$(uci get modem.modem$CURRMODEM.commport)
idV=$(uci get modem.modem$CURRMODEM.uVid)
idP=$(uci get modem.modem$CURRMODEM.uPid)

chkquectel
if $QUECTEL; then
	case $NEWMOD in
		"1" )
			ATCMDD='AT+QCFG="usbnet",0'
		;;
		"2" )
			ATCMDD='AT+QCFG="usbnet",2'
		;;
		"3" )
			ATCMDD='AT+QCFG="usbnet",1'
		;;
	esac
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
fi

 chksierra
 if [ $SIERRAID -eq 1 ]; then
	ATCMDD='AT!ENTERCND="A710"'
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	
	case $idP in
		"68c0"|"9041"|"901f" ) # MC7354 EM/MC7355
			case $NEWMOD in
				"1" )
					ATCMDD='at!UDUSBCOMP=6'
				;;
				"2" )
					ATCMDD='at!UDUSBCOMP=8'
				;;
			esac
		;;
		"9070"|"9071"|"9078"|"9079"|"907a"|"907b" ) # EM/MC7455
			case $NEWMOD in
				"1" )
					ATCMDD='at!usbcomp=1,1,10d'
				;;
				"2" )
					ATCMDD='at!usbcomp=1,1,1009'
				;;
			esac
		;;
		"9090"|"9091"|"90b1" ) # EM7565
			case $NEWMOD in
				"1" )
					ATCMDD='at!usbcomp=1,3,10d'
				;;
				"2" )
					ATCMDD='AT!USBCOMP=1,3,1009'
				;;
			esac
		;;
	esac
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	ATCMDD='AT!ENTERCND="AWRONG"'
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
 fi

ATCMDD="AT+CFUN=1,1"
OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
log "Hard modem reset done on /dev/ttyUSB$CPORT to reload drivers"
ifdown wan$CURRMODEM
uci delete network.wan$CURRMODEM
uci set network.wan$CURRMODEM=interface
uci set network.wan$CURRMODEM.proto=dhcp
uci set network.wan$CURRMODEM.${ifname1}="wan"$CURRMODEM
uci set network.wan$CURRMODEM.metric=$CURRMODEM"0"
uci commit network
/etc/init.d/network reload
ifdown wan$CURRMODEM
echo "1" > /tmp/modgone
log "Setting Modem Removal flag (1)"
