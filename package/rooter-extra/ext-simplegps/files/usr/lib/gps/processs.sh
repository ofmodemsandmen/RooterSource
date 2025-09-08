#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	logger -t "Quectel GPS" "$@"
}

convert=$(uci -q get gps.configuration.convert)
datefor=$(uci -q get gps.configuration.datefor)

OX=$1

if [ -z "$OX" ]; then
	if [ -e /tmp/lastgps ]; then
		OX=$(cat /tmp/lastgps)
	else
		exit 0
	fi
else
	OX=$(cat /tmp/gpsox)
	echo "$OX" > /tmp/lastgps
fi

O=$(echo "$OX" | grep "at!gpsloc?")
if [ -z "$O" ]; then
	exit 0
fi

CURRMODEM=1
CPORT=$(uci get modem.modem$CURRMODEM.commport)
ATCMDD="at!gpssatinfo?"
OY=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
echo "$OY" > /tmp/satgps
Y=$(cat /tmp/satgps)
OY=$(echo $Y" " | tr " " ",")


OX=$(echo $OX" " | tr " " ",")
LATD=$(echo $OX | cut -d, -f3)
LATM=$(echo $OX | cut -d, -f5)
LATS=$(echo $OX | cut -d, -f7)
LATH=$(echo $OX | cut -d, -f9)

LOND=$(echo $OX | cut -d, -f12)
LONM=$(echo $OX | cut -d, -f14)
LONS=$(echo $OX | cut -d, -f16)
LONH=$(echo $OX | cut -d, -f18)
lathemid=$LATH
lonhemid=$LONH

TIME=$(echo $OX | cut -d, -f25)
year=$(echo $OY | cut -d, -f6)
YEAR="${year#"${year%%[!(]*}"}"
MON=$(echo $OY | cut -d, -f7)
DAY=$(echo $OY | cut -d, -f8)

if [ $LATH = "S" ]; then
	LATH="South"
else
	LATH="North"
fi
if [ $LONH = "E" ]; then
	LONH="East"
else
	LONH="West"
fi
delatitude=$LATD" Deg "$LATM" Min "$LATS" Sec "$LATH
delongitude=$LOND" Deg "$LONM" Min "$LONS" Sec "$LONH
/usr/lib/gps/convert.lua $LATD $LATM $LATS $lathemid 1
source /tmp/latlon
dlatitude=$CONVERT
/usr/lib/gps/convert.lua $LOND $LONM $LONS $lonhemid 1
source /tmp/latlon
dlongitude=$CONVERT

if [ $convert = '0' ]; then
	latitude=$LATD" Deg "$LATM" Min "$LATS" Sec "$LATH
	longitude=$LOND" Deg "$LONM" Min "$LONS" Sec "$LONH
else
	latitude=$dlatitude
	longitude=$dlongitude
fi


if [ $datefor = '0' ]; then
	date=$YEAR"-"$MON"-"$DAY" "$TIME" (UTC)"
else
	date=$DAY"/"$MON"/"$YEAR" "$TIME" (UTC)"
fi

FIX=$(echo $OX | cut -d, -f39)
fix=$FIX" Fix"
ALT=$(echo $OX | cut -d, -f42)
altitude=$ALT" M"
COG=$(echo $OX | cut -d, -f48)
if [ -z $COG ]; then
	heading="Stationary"
else
	heading=$COG" Deg from North"
fi
HOP=$(echo $OX | cut -d, -f51)
hspd=$HOP" M/second"
VOP=$(echo $OX | cut -d, -f54)
vertp=$VOP" M/second"
Prec=$(echo $OX | cut -d, -f37)
horizp=$Prec" M"

numsat=$(echo $OY | cut -d, -f5)

echo $date > /tmp/gpsdata
echo $altitude >> /tmp/gpsdata
echo $latitude >> /tmp/gpsdata
echo $longitude >> /tmp/gpsdata
echo $numsat >> /tmp/gpsdata
echo $horizp >> /tmp/gpsdata
echo $fix >> /tmp/gpsdata
echo $heading >> /tmp/gpsdata
echo $hspd >> /tmp/gpsdata
echo $vertp >> /tmp/gpsdata
echo $dlatitude >> /tmp/gpsdata
echo $dlongitude >> /tmp/gpsdata
echo $delatitude >> /tmp/gpsdata
echo $delongitude >> /tmp/gpsdata

lat="$delatitude ( $dlatitude )"
long="$delongitude ( $dlongitude )"
echo "$lat" > /tmp/gpsdata1
echo "$long" >> /tmp/gpsdata1

echo "0" > /tmp/gps
