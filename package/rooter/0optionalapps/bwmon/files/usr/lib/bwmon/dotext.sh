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
			read -r line
			useda=$line
			return
		done < /tmp/bwdata
	else
		used="0"
		useda="0.00 K"
	fi
}

sendmsg() {
	getbw
	/usr/lib/bwmon/amtleft.lua $alloc $used
	bwleft=$(cat /tmp/amtleft)
	
	ident=$(uci -q get custom.texting.ident)
	#ident="ICCID "$(uci -q get modem.modem1.iccid)
	if [ -z "$ident" ]; then
		ident="John Doe"
	fi
	message="$ident has used $useda bandwidth and has $bwleft of bandwidth left"
	
	tore=$(uci -q get custom.texting.tore)
	if [ $tore = '0' ]; then
		phone=$(uci -q get custom.texting.phone)
		/usr/lib/bwmon/chksms.sh
		if [ -e /tmp/texting ]; then
				/usr/lib/sms/smsout.sh "$phone" "$message" 
				log "$phone $message"
		else
			log "$message not sent. No SMS."
		fi
	else
		email=$(uci -q get custom.texting.email)
		
		STEMP="/tmp/emailmsg"
		MSG="/usr/lib/bwmon/message"
		rm -f $STEMP
		cp $MSG $STEMP
		sed -i -e "s!#EMAIL#!$email!g" $STEMP
		sed -i -e "s!#MESSAGE#!$message!g" $STEMP
		mess=$(cat /tmp/emailmsg)
		echo -e "$mess" | msmtp $email
		log "$email $message"
	fi
	
}

sendmsg