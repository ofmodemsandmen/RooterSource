#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "TEXTING" "$@"
}

checktime() {
	SHOUR=$(uci -q get custom.bwallocate.time)
	EHOUR=`expr $SHOUR + 1`
	if [ $EHOUR -gt 95 ]; then
		EHOUR=0
	fi
	HOUR=`expr $SHOUR / 4`
	let "TH = $HOUR * 4"
	let "TMP1 = $SHOUR - $TH"
	let "MIN = $TMP1 * 15"
	shour=$HOUR
	smin=$MIN
	
	HOUR=`expr $EHOUR / 4`
	let "TH = $HOUR * 4"
	let "TMP1 = $EHOUR - $TH"
	let "MIN = $TMP1 * 15"
	ehour=$HOUR
	emin=$MIN
	
	chour=$(date +%H)
	cmin=$(date +%M)
	if [ $shour -gt $chour ]; then
		flag="0"
	else
		if [ $shour -eq $chour ]; then
			if [ $smin -le $cmin ]; then
				flag="1"
			else
				flag="0"
			fi
		else
			flag="1"
		fi
	fi

	if [ $flag = "1" ]; then
		if [ $ehour -lt $chour ]; then
			flag="0"
		else
			if [ $ehour -eq $chour ]; then
				if [ $emin -lt $cmin ]; then
					flag="0"
				else
					flag="1"
				fi
			else
				flag="1"
			fi
		fi
	fi
	echo $flag
}

delay=900
while true
do
	EN=$(uci -q get custom.bwallocate.enabled)
	if [ $EN = "1" ]; then
		running=$(checktime)
		if [ $running = "1" ]; then
			EN=$(uci -q get custom.bwallocate.text)
			if [ $EN = "1" ]; then
				/usr/lib/bwmon/dotext.sh
				sleep $delay
			fi
		else
			sleep $delay
		fi
	else
		sleep $delay
	fi
done