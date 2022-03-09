#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "TEXTING" "$@"
}

checktime() {
	SHOUR=$(uci -q get custom.texting.time)
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

getbw() {
	alloc=$(uci -q get custom.bwallocate.allocate)"000000"
	if [ -e /tmp/bwdata ]; then
		while IFS= read -r line; do
			days=$line
			if [ $days = '0' ]; then
				used="0"
				return
			fi
			read -r line
			used=$line
			return
		done < /tmp/bwdata
	else
		used="0"
	fi
}

checkamt() {
	istime=$(checktime)
	if [ $istime = '1' ]; then
		prev=$(uci -q get custom.texting.used)
		incr=$(uci -q get custom.texting.increment)
		getbw
		/usr/lib/bwmon/datainc.lua $prev $incr $used
		source /tmp/bwinc
		uci set custom.texting.used=$prev
		uci commit custom
		echo $runn
	else
		echo "0"
	fi
}

delay=900
while true
do
	EN=$(uci -q get custom.bwallocate.enabled)
	if [ $EN = "1" ]; then
		MT=$(uci -q get custom.texting.method)
		if [ $MT = '0' ]; then
			days=$(uci -q get custom.texting.days)
			daysdate=$( date +%d )
			daysdate="${daysdate#"${daysdate%%[!0]*}"}"
			remain=$((daysdate % days))
			if [ $remain -eq 0 ]; then
				running=$(checktime)
			else
				running="0"
			fi
		else
			running=$(checkamt)
		fi
		if [ $running = "1" ]; then
			EN=$(uci -q get custom.texting.text)
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