#!/bin/sh

LAN_TYPE=$(uci get network.lan.ipaddr | awk -F. ' { print $1"."$2 }')
LEASES_FILE=/tmp/dhcp.leases
lockDir=/tmp/WRTbmon

[ ! -d "$lockDir" ] && mkdir "$lockDir"
basePath="/tmp/bwmon/"
mkdir -p $basePath"data"
dataPath=$basePath"data/"
backPath=/opt/WRTbmon/data/
mkdir -p "/opt/WRTbmon/data/"
STARTIMEX=$(date +%s)
STARTIMEY=$(date +%s)
STARTIMEZ=$(date +%s)
cYear=$(date +%Y)
cDay=$(date +%d)
cMonth=$(date +%m)
setup_time=60
update_time=300
backup_time=1200
pause=30
unlimited="peak"

log() {
	logger -t "wrtbwmon" "$@"
}

lock()
{
	while [ -f /tmp/wrtbwmon.lock ]; do
		if [ ! -d /proc/$(cat /tmp/wrtbwmon.lock) ]; then
			log "WARNING : Lockfile detected but process $(cat /tmp/wrtbwmon.lock) does not exist !"
			rm -f /tmp/wrtbwmon.lock
		fi
		sleep 1
	done
	echo $$ > /tmp/wrtbwmon.lock
}

unlock()
{
	rm -f /tmp/wrtbwmon.lock
}

setup()
{
	#Create the RRDIPT CHAIN (it doesn't matter if it already exists).
	iptables -N RRDIPT 2> /dev/null

	#Add the RRDIPT CHAIN to the FORWARD chain (if non existing).
	iptables -L FORWARD --line-numbers -n | grep "RRDIPT" | grep "1" > /dev/null
	if [ $? -ne 0 ]; then
		iptables -L FORWARD -n | grep "RRDIPT" > /dev/null
		if [ $? -eq 0 ]; then
			log "DEBUG : iptables chain misplaced, recreating it..."
			iptables -D FORWARD -j RRDIPT
		fi
		iptables -I FORWARD -j RRDIPT
	fi

	#For each host in the ARP table
	grep ${LAN_TYPE} /proc/net/arp | while read IP TYPE FLAGS MAC MASK IFACE
	do
		#Add iptable rules (if non existing).
		iptables -nL RRDIPT | grep "${IP} " > /dev/null
		if [ $? -ne 0 ]; then
			iptables -I RRDIPT -d ${IP} -j RETURN
			iptables -I RRDIPT -s ${IP} -j RETURN
		fi
	done
}

update()
{
	[ ! -f "${1}" -a -f /etc/config/usage.db ] && cp /etc/config/usage.db ${1}
	lock
	
	#Read and reset counters
	iptables -L RRDIPT -vnxZ -t filter > /tmp/traffic_$$.tmp
	wan=$(ubus -S call network.interface.wan status | jsonfilter -e '@.device' )
	if [ -z $wan ]; then
		wan="xxxx"
	fi
	grep -v "0x0" /proc/net/arp | grep ${LAN_TYPE} | grep -v "$wan" | while read IP TYPE FLAGS MAC MASK IFACE
	do
		grep ${IP} /tmp/traffic_$$.tmp | while read PKTS BYTES TARGET PROT OPT IFIN IFOUT SRC DST
		do
			[ "${DST}" = "${IP}" ] && echo $((${BYTES}/1000)) > /tmp/in_$$.tmp
			[ "${SRC}" = "${IP}" ] && echo $((${BYTES}/1000)) > /tmp/out_$$.tmp
		done
		IN=$(cat /tmp/in_$$.tmp)
		OUT=$(cat /tmp/out_$$.tmp)
		rm -f /tmp/in_$$.tmp
		rm -f /tmp/out_$$.tmp
		if [ ${IN} -gt 0 -o ${OUT} -gt 0 ];  then
			LINE=$(grep ${MAC} ${1})
			if [ -z "${LINE}" ]; then
				PEAKUSAGE_IN=0
				PEAKUSAGE_OUT=0
				OFFPEAKUSAGE_IN=0
				OFFPEAKUSAGE_OUT=0
			else
				PEAKUSAGE_IN=$(echo ${LINE} | cut -f2 -s -d, | awk -F: ' { print $2 }' | sed 's/"//g' )
				PEAKUSAGE_OUT=$(echo ${LINE} | cut -f3 -s -d, | awk -F: ' { print $2 }' | sed 's/"//g' )
				OFFPEAKUSAGE_IN=$(echo ${LINE} | cut -f4 -s -d, | awk -F: ' { print $2 }' | sed 's/"//g' )
				OFFPEAKUSAGE_OUT=$(echo ${LINE} | cut -f5 -s -d, | awk -F: ' { print $2 }' | sed 's/"//g' )
			fi
			
			if [ "${2}" = "offpeak" ]; then
				OFFPEAKUSAGE_IN=$((${OFFPEAKUSAGE_IN}+${IN}))
				OFFPEAKUSAGE_OUT=$((${OFFPEAKUSAGE_OUT}+${OUT}))
			else
				PEAKUSAGE_IN=$((${PEAKUSAGE_IN}+${IN}))
				PEAKUSAGE_OUT=$((${PEAKUSAGE_OUT}+${OUT}))
			fi

			for USERSFILE in /tmp/dhcp.leases /tmp/dnsmasq.conf /etc/dnsmasq.conf /etc/hosts; do
				[ -e "$USERSFILE" ] || continue
				case $USERSFILE in
	    				/tmp/dhcp.leases )
						NAME=$(grep -i "$MAC" $USERSFILE | cut -f4 -s -d' ')
					;;
	    				/etc/hosts )
						NAME=$(grep "^$IP " $USERSFILE | cut -f2 -s -d' ')
					;;
	    				* )
						NAME=$(grep -i "$MAC" "$USERSFILE" | cut -f2 -s -d,)
					;;
				esac
				[ "$NAME" = "*" ] && NAME=
				[ -n "$NAME" ] && break
    			done

			#NAME=$(cat $LEASES_FILE | grep ${LAN_TYPE} | grep ${MAC} | awk -F[\ ] ' { print $4 }')
			if [ -z $NAME ]; then
				NAME="*"
			fi
			grep -v "${MAC}" ${1} > /tmp/db_$$.tmp
			mv /tmp/db_$$.tmp ${1}
			echo "\"mac\":\""${MAC}"\"","\"down\":\""${PEAKUSAGE_IN}"\"","\"up\":\""${PEAKUSAGE_OUT}"\"","\"offdown\":\""${OFFPEAKUSAGE_IN}"\"","\"offup\":\""${OFFPEAKUSAGE_OUT}"\"","\"ip\":\""${IP}"\"","\"name\":\""${NAME}"\"" >> ${1}
		fi
	done
	rm -f /tmp/*_$$.tmp
	unlock
}


createFiles() 
{
	dailyUsageDB="$dataPath$cYear-$cMonth-$cDay-daily_data.js"
	dailyUsageBack="$backPath$cYear-$cMonth-$cDay-daily_data.js"
	if [ ! -f $dailyUsageBack ]; then
		touch $dailyUsageDB
	else
		cp -f $dailyUsageBack $dailyUsageDB
	fi
	monthlyUsageDB="$dataPath$cYear-$cMonth-mac_data.js"
	monthlyUsageBack="$backPath$cYear-$cMonth-mac_data.js"
	if [ -f $monthlyUsageBack ]; then
		cp -f $monthlyUsageBack $monthlyUsageDB".bk"
		sed "/start day $cDay/,/end day $cDay/d" $monthlyUsageDB".bk" > $monthlyUsageDB 
		rm -f $monthlyUsageDB".bk"
	else
		touch $monthlyUsageDB
	fi
}

shutDown() 
{
	cp -f $dailyUsageDB $dailyUsageBack 
	cp -f $monthlyUsageDB $monthlyUsageDB".bk"
	echo "start day $cDay" >> $monthlyUsageDB".bk"
	cat "$dailyUsageDB" >> $monthlyUsageDB".bk"
	echo "end day $cDay" >> $monthlyUsageDB".bk"
	cp -f $monthlyUsageDB".bk" $monthlyUsageBack
	rm -f $monthlyUsageDB".bk"
	log "Cleanup backup"
	lua /opt/WRTbmon/cleanup.lua
}

checkSetup() 
{
	CURRTIME=$(date +%s)
	let ELAPSE=CURRTIME-STARTIMEX
	if [ $ELAPSE -gt $setup_time ]; then
		STARTIMEX=$CURRTIME
		setup
	fi
}

checkUpdate() 
{
	CURRTIME=$(date +%s)
	let ELAPSE=CURRTIME-STARTIMEY
	if [ $ELAPSE -gt $update_time ]; then
		STARTIMEY=$CURRTIME
		update $dailyUsageDB $unlimited
	fi
}

checkBackup() 
{
	CURRTIME=$(date +%s)
	let ELAPSE=CURRTIME-STARTIMEZ
	if [ $ELAPSE -gt $backup_time ]; then
		STARTIMEZ=$CURRTIME
		shutDown
	fi
}

checkTime() 
{
	pDay=$(date +%d)
	pYear=$(date +%Y)
	pMonth=$(date +%m)
	if [ "$cDay" -ne "$pDay" ]; then
		echo "start day $cDay" >> $monthlyUsageDB
		cat "$dailyUsageDB" >> $monthlyUsageDB
		echo "end day $cDay" >> $monthlyUsageDB
		cp -f $monthlyUsageDB $monthlyUsageBack
		cDay=$pDay
		rm -f $dataPath[[:digit:]][[:digit:]][[:digit:]][[:digit:]]"-"[[:digit:]][[:digit:]]"-"[[:digit:]][[:digit:]]-daily_data.js
		rm -f $backPath[[:digit:]][[:digit:]][[:digit:]][[:digit:]]"-"[[:digit:]][[:digit:]]"-"[[:digit:]][[:digit:]]-daily_data.js
		if [ "$cMonth" -ne "$pMonth" ]; then
			cMonth=$pMonth
			cYear=$pYear
			monthlyUsageDB="$dataPath$cYear-$cMonth-mac_data.js"
			monthlyUsageBack="$backPath$cYear-$cMonth-mac_data.js"
			touch $monthlyUsageDB
		fi
		rm -f $dailyUsageDB
		rm -f $dailyUsageBack
		dailyUsageDB="$dataPath$cYear-$cMonth-$cDay-daily_data.js"
		touch $dailyUsageDB
		dailyUsageBack="$backPath$cYear-$cMonth-$cDay-daily_data.js"
	fi 
	unlimited="peak"
	hasUnlimited=$(uci get bwmon.bwmon.unlimited_usage)
	if [ $hasUnlimited = 1 ]; then
		unlimited_start=$(uci get bwmon.bwmon.unlimited_start)
		unlimited_end=$(uci get bwmon.bwmon.unlimited_end)
		ul_start=$(date -d "$unlimited_start" +%s);
		ul_end=$(date -d "$unlimited_end" +%s);
		[ "$ul_end" -lt "$ul_start" ] && ul_start=$((ul_start - 86400))
		currTime=$(date +%s)
		inUnlimited=$((currTime >= ul_start && currTime <= ul_end))
		if [ "$inUnlimited" -eq "1" ]; then
			unlimited="offpeak"
		fi
	fi
}

createFiles
setup
while [ -d $lockDir ]; do
	checkSetup
	checkTime
	checkUpdate
	checkBackup
	n=0
	while [ true ] ; do
		n=$(($n + 1))
		if [ ! -d "$lockDir" ]; then
			shutDown
			exit 0
		fi
		[ "$n" -gt "$pause" ] && break;
		sleep 1
	done
done
