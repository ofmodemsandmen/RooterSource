#!/bin/sh


tping() {
	hp=$(httping $2 -t $TIMEOUT -c 3 -s $1)
	pingg=$(echo $hp" " | grep -o "round-trip .\+ ms ")
	if [ -z "$pingg" ]; then
		tmp=0
	else
		tmp=200
	fi
}

OX=$1
CURRMODEM=$2

MCC=$(sed -n '12p' /tmp/status$CURRMODEM.file)
if [ -z "$MCC" ]; then
	MCC='-'
fi
MNC=$(sed -n '13p' /tmp/status$CURRMODEM.file)
MNC=${MNC:1}
if [ -z "$MNC" ]; then
	MNC='-'
fi

connect=$(uci get modem.modem$CURRMODEM.connected)
if [ -z "$connect" ]; then
	connect='0'
fi
if [ "$connect" = "0" ]; then
	TIMEOUT=10
	ipv41="http://www.google.com/"
	tping "$ipv41"; RETURN_CODE_1=$tmp
	if [ "$RETURN_CODE_1" != "200" ]; then
		connect='0'
	else
		connect='1'
	fi
fi

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

O=$(echo "$OX" | grep '$GPGGA')
if [ -z "$O" ]; then
	exit 0
fi

OXE=${OX//,N/"N"}
OXE=${OXE//,S/"S"}
OXE=${OXE//,E/"E"}
OX=${OXE//,W/"W"}

convert=$(uci -q get gps.configuration.convert)
datefor=$(uci -q get gps.configuration.datefor)

TIME=$(echo $OX | cut -d, -f2)
LAT=$(echo $OX | cut -d, -f3)
LON=$(echo $OX | cut -d, -f4)
ALT=$(echo $OX | cut -d, -f8)
NSAT=$(echo $OX | cut -d, -f6)
HOP=$(echo $OX | cut -d, -f7)

altitude=$ALT" M"
if [ -z "$ALT" ]; then
	fix="2D Fix"
else
	fix="3D Fix"
fi
numsat=$NSAT
numsat="${numsat#"${numsat%%[!0]*}"}"
horizp=$HOP

TIME="${TIME#"${TIME%%[! ]*}"}"
hr=${TIME:0:2}
min=${TIME:2:2}
sec=${TIME:4:2}
if [ $hr -lt 12 ]; then
	apm="AM"
else
	apm="PM"
fi
time=$hr":"$min":"$sec" "$apm" (UTC)"

llen=$(expr length "$LAT")
if [ $llen -eq 12 ]; then
	LAT="0"$LAT
fi
if [ $llen -eq 11 ]; then
	LAT="00"$LAT
fi
llen=$(expr length "$LON")

if [ $llen -eq 12 ]; then
	LON="0"$LON
fi
if [ $llen -eq 11 ]; then
	LON="00"$LON
fi

latdeg=${LAT:0:3}
latmin=${LAT:3:2}
latsec=${LAT:6:4}
latsec=$(echo $latsec | sed 's/^0*//')
lathemi=${LAT:12:1}
londeg=${LON:0:3}
lonmin=${LON:3:2}
lonsec=${LON:6:4}
lonsec=$(echo $lonsec | sed 's/^0*//')
lonhemi=${LON:12:1}
lathemid=$lathemi
lonhemid=$lonhemi

let "latsecd=$latsec*6/1000"
let "lonsecd=$lonsec*6/1000"

latdeg="${latdeg#"${latdeg%%[!0]*}"}"
if [ -z "$latdeg" ]; then
	latdeg="0"
fi
latmin="${latmin#"${latmin%%[!0]*}"}"
if [ -z "$latmin" ]; then
	latmin="0"
fi
if [ $lathemi = "S" ]; then
	lathemi="South"
else
	lathemi="North"
fi
delatitude=$latdeg" Deg "$latmin" Min "$latsecd" Sec "$lathemi
if [ $lonhemi = "E" ]; then
	lonhemi="East"
else
	lonhemi="West"
fi
londeg="${londeg#"${londeg%%[!0]*}"}"
if [ -z "$londeg" ]; then
	londeg="0"
fi
lonmin="${lonmin#"${lonmin%%[!0]*}"}"
if [ -z "$lonmin" ]; then
	lonmin="0"
fi
delongitude=$londeg" Deg "$lonmin" Min "$lonsecd" Sec "$lonhemi
/usr/lib/gps/convert.lua $latdeg $latmin $latsec $lathemid
source /tmp/latlon
dlatitude=$CONVERT
/usr/lib/gps/convert.lua $londeg $lonmin $lonsec $lonhemid
source /tmp/latlon
dlongitude=$CONVERT

if [ $convert = '0' ]; then
	latitude=$latdeg" Deg "$latmin" Min "$latsecd" Sec "$lathemi
	longitude=$londeg" Deg "$lonmin" Min "$lonsecd" Sec "$lonhemi
else
	latitude=$dlatitude
	longitude=$dlongitude
fi

echo $time > /tmp/gpsdatax$CURRMODEM
echo $altitude >> /tmp/gpsdatax$CURRMODEM
echo $latitude >> /tmp/gpsdatax$CURRMODEM
echo $longitude >> /tmp/gpsdatax$CURRMODEM
echo $numsat >> /tmp/gpsdatax$CURRMODEM
echo $horizp >> /tmp/gpsdatax$CURRMODEM
echo $fix >> /tmp/gpsdatax$CURRMODEM
echo "0.0 deg" >> /tmp/gpsdatax$CURRMODEM
echo "0.0 Km/h" >> /tmp/gpsdatax$CURRMODEM
echo "0.0 Km/h" >> /tmp/gpsdatax$CURRMODEM
echo $dlatitude >> /tmp/gpsdatax$CURRMODEM
echo $dlongitude >> /tmp/gpsdatax$CURRMODEM
echo $delatitude >> /tmp/gpsdatax$CURRMODEM
echo $delongitude >> /tmp/gpsdatax$CURRMODEM
echo "$connect" >> /tmp/gpsdatax$CURRMODEM
echo "$MCC" >> /tmp/gpsdatax$CURRMODEM
echo "$MNC" >> /tmp/gpsdatax$CURRMODEM

lat="$delatitude ( $dlatitude )"
long="$delongitude ( $dlongitude )"
echo "$lat" > /tmp/gpsdata$CURRMODEM
echo "$long" >> /tmp/gpsdata$CURRMODEM

echo "0" > /tmp/gps$CURRMODEM
