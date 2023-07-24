#!/bin/sh
. /lib/functions.sh

log() {
	modlog "TEXTING" "$@"
}

checktime() {
	SHOUR=$(uci -q get custom.texting.time)
	EHOUR=`expr $SHOUR + 1`
	if [ $EHOUR -gt 95 ]; then
		EHOUR=0
	fi
	HOUR=`expr $SHOUR / 4`
	let "TH=$HOUR*4"
	let "TMP1=$SHOUR-$TH"
	let "MIN=$TMP1*15"
	shour=$HOUR
	smin=$MIN
	
	HOUR=`expr $EHOUR / 4`
	let "TH=$HOUR*4"
	let "TMP1=$EHOUR-$TH"
	let "MIN=$TMP1*15"
	ehour=$HOUR
	emin=$MIN
	
	chour=$(date +%H)
	cmin=$(date +%M)
	if [ $shour -gt $chour ]; then
		istime="0"
	else
		if [ $shour -eq $chour ]; then
			if [ $smin -le $cmin ]; then
				istime="1"
			else
				istime="0"
			fi
		else
			istime="1"
		fi
	fi

	if [ $istime = "1" ]; then
		if [ $ehour -lt $chour ]; then
			istime="0"
		else
			if [ $ehour -eq $chour ]; then
				if [ $emin -lt $cmin ]; then
					istime="0"
				else
					istime="1"
				fi
			else
				istime="1"
			fi
		fi
	fi
}

getbw() {
	alloc=$(uci -q get custom.bwallocate.allocate)"000000000"
	if [ -e /tmp/bwdata ]; then
		while IFS= read -r line; do
			days=$line
			if [ $days = '0' ]; then
				used="0"
				return
			fi
			read -r line
			used="$line"
			return
		done < /tmp/bwdata
	else
		used="0"
	fi
}

checkamt() {
	checktime
	if [ $istime = '1' ]; then
		incr=$(uci -q get custom.texting.increment)
		prev=$(uci -q get custom.texting.used)
		getbw
		if [ -z "$prev" ]; then
			prev=0
		fi
		/usr/lib/bwmon/datainc.lua $prev $incr $used
		source /tmp/bwinc
		uci set custom.texting.used="$prev"
		uci commit custom
		running=$runn
	else
		running="0"
	fi
}

checkper() {
	checktime
	if [ $istime = '1' ]; then
		prev=$(uci -q get custom.texting.used)
		per=$(uci -q get custom.texting.percent)
		persent=$(uci -q get custom.bwallocate.persent)
		if [ "$persent" != "1" ]; then
			getbw
			/usr/lib/bwmon/dataper.lua $alloc $per $used
			source /tmp/bwper
			if [ $runn = "1" ]; then
				uci set custom.bwallocate.persent="1"
				uci commit custom
			fi
			running=$runn
		else
			running="0"
		fi
	else
		running="0"
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
			if [ $MT = '1' ]; then
				checkamt
			else
				checkper
			fi
		fi
		if [ $running = "1" ]; then
			EN=$(uci -q get custom.texting.text)
			if [ $EN = "1" ]; then
				/usr/lib/bwmon/dotext.sh &
				sleep $delay
			fi
		else
			sleep $delay
		fi
	else
		sleep $delay
	fi
done