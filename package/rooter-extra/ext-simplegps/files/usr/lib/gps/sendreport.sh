#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "SEND REPORTS" "$@"
}

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

rtype=$1
baselat=$2
baselon=$3

sendemail() {
	host=$(uci -q get gps.configuration.smtp)
	if [ -z $host ]; then
		return
	fi
	user=$(uci -q get gps.configuration.euser)
	if [ -z $user ]; then
		return
	fi
	pass=$(uci -q get gps.configuration.epass)
	if [ -z $pass ]; then
		return
	fi
	STEMP="/tmp/eemail"
	MSG="/usr/lib/gps/msmtprc"
	DST="/etc/msmtprc"
	rm -f $STEMP
	cp $MSG $STEMP
	sed -i -e "s!#HOST#!$host!g" $STEMP
	sed -i -e "s!#USER#!$user!g" $STEMP
	sed -i -e "s!#PASS#!$pass!g" $STEMP
	mv $STEMP $DST
	
	email=$(uci -q get gps.configuration.email)	
	if [ -z "$email" ]; then
		return
	fi

	message='\n'$(cat /tmp/messg)
	STEMP="/tmp/emailmsg"
	rm -f $STEMP
	echo "From: GPS Info <$user>" >> $STEMP
	echo "To: $email" >> $STEMP
	echo "Subject: GPS Info" >> $STEMP
	echo "$message" >> $STEMP
	mess=$(cat $STEMP)
	echo -e "$mess" | msmtp --read-envelope-from --read-recipients
}

chksms() {
	CURRMODEM=1
	rm -f /tmp/texting
	CPORT=$(uci -q get modem.modem$CURRMODEM.commport)
	if [ -z $CPORT ]; then
		return
	fi
	SMS_OK=$(uci -q get modem.modem$CURRMODEM.sms)
	if [ "$SMS_OK" != "1" ]; then
		return
	fi 
	echo "0" > /tmp/texting
}

msgsending() {
	sendby=$(uci -q get gps.configuration.sendby)
	if [ $sendby = "0" -o $sendby = "2" ]; then
		phone=$(uci -q get gps.configuration.phone)
		messaget=$(cat /tmp/messgt)
		if [ ! -z "$phone" ]; then
			chksms
			if [ -e /tmp/texting ]; then
				/usr/lib/sms/smsout.sh "$phone" "$messaget" 
			fi
		fi
	fi
	if [ $sendby = "1" -o $sendby = "2" ]; then
		sendemail
	fi
}

sendmsg() {
	rm -f /tmp/messg
	rm -f /tmp/messgt
	while IFS= read -r line; do
		date=$line
		read -r line
		altitude=$line
		read -r line
		latitude=$line
		read -r line
		longitude=$line
		read -r line
		numsat=$line
		read -r line
		horizp=$$line
		read -r line
		fix=$line
		read -r line
		heading=$line
		read -r line
		hspd=$line
		read -r line
		vspd=$line
		read -r line
		dlatitude=$line
		read -r line
		dlongitude=$line
		read -r line
		delatitude=$line
		read -r line
		delongitude=$line
		break
	done < /tmp/gpsdata
	zoom=$(uci -q get gps.configuration.zoom)
	url_string="https://maps.google.com/maps"
	qstr=$dlatitude","$dlongitude
	mapURL=$url_string"?q="$qstr"&z="$zoom
	name=$(uci -q get gps.configuration.name)
	if [ -z "$name" ]; then
		name="None"
	fi
	if [ "$rtype" = "0" -o "$rtype" = "2" ]; then
		echo "Moved" >> /tmp/messgt
	fi
	echo "$name" >> /tmp/messgt
	echo "($dlatitude : $dlongitude) $altitude" >> /tmp/messgt
	echo "$mapURL" >> /tmp/messgt
	
	if [ $rtype = "3" ]; then
		echo "Report Test" >> /tmp/messg
	fi
	echo "Identifier Text    : $name" >> /tmp/messg
	echo "Current Latitude   : $delatitude ( $dlatitude )" >> /tmp/messg
	echo "Current Longitude  : $delongitude ( $dlongitude )" >> /tmp/messg
	echo "Current Altitude   : $altitude" >> /tmp/messg
	if [ "$rtype" = "1" -o "$rtype" = "2" ]; then
		if [ $rtype = "1" ]; then
			echo "      Position is Changing" >> /tmp/messg
		else
			echo "      Position has Changed and Stopped" >> /tmp/messg
		fi
		echo "Previous Latitude  : $baselat" >> /tmp/messg
		echo "Previous Longitude : $baselon" >> /tmp/messg
		echo "Current Heading    : $heading" >> /tmp/messg
		echo "Current HorzSpeed  : $hspd" >> /tmp/messg
		echo "Current VertSpeed  : $vspd" >> /tmp/messg
	fi
	echo " " >> /tmp/messg
	echo "      Current Map Location" >> /tmp/messg
	echo "$mapURL" >> /tmp/messg
	msgsending
}

if [ "$rtype" = "3" ]; then
	if [ -e /tmp/gps -a -e /tmp/gpsdata ]; then
		sendmsg
	else
		name=$(uci -q get gps.configuration.name)
		if [ -z "$name" ]; then
			name="None"
		fi
		rm -f /tmp/messg
		rm -f /tmp/messgt
		echo "Report Test Message" >> /tmp/messgt
		echo "$name" >> /tmp/messgt
		echo "Report Test Message" >> /tmp/messg
		echo "Identifier Text    : $name" >> /tmp/messg
		msgsending
	fi
else
	if [ -e /tmp/gps -a -e /tmp/gpsdata ]; then
		sendmsg
	fi
fi