#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "TEXTING" "$@"
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

sendmsg() {
	phone=$(uci -q get custom.bwallocate.phone)
	ident=$(uci -q get custom.bwallocate.ident)
	if [ -z $ident ]; then
		ident="John Doe"
	fi
	getbw
	/usr/lib/bwmon/amtleft.lua $alloc $used
	bwleft=$(cat /tmp/amtleft)

	message="$ident has $bwleft of bandwidth left"
	/usr/lib/bwmon/chksms.sh
	if [ -e /tmp/texting ]; then
			/usr/lib/sms/smsout.sh "$phone" "$message" 
			log "$phone $message"
	else
		log "$message not sent. No SMS."
	fi
	
}

sendmsg