#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "REPORTS" "$@"
}

log "Handle Reports"

docron() {
	tnum=$1
	timex=$(uci -q get gps.configuration.time$tnum)
	if [ -z "$timex" ]; then
		return
	fi
	SHOUR=$timex
	HOUR=`expr $SHOUR / 4`
	let "TH = $HOUR * 4"
	let "TMP1 = $SHOUR - $TH"
	let "MIN = $TMP1 * 15"
	echo "$MIN $HOUR * * * /usr/lib/gps/sendreport.sh" >> /etc/cronuser
}

if [ ! -e /tmp/gps ]; then
	log "No GPS data"
	exit 0
fi

rm -f /etc/cronuser
times=$(uci -q get gps.configuration.times)
if [ -z "$times" ]; then
	times="0"
fi
if [ $times -gt 0 ]; then
	case $times in
	"1" )
		docron 1
	;;
	"2" )
		docron 1
		docron 2
	;;
	"3" )
		docron 1
		docron 2
		docron 3
	;;
	"4" )
		docron 1
		docron 2
		docron 3
		docron 4
	;;
	"5" )
		docron 1
		docron 2
		docron 3
		docron 4
		docron 5
	;;
	esac
fi
/usr/lib/rooter/luci/croncat.sh