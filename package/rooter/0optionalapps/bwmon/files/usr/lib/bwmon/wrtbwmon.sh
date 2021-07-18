#!/bin/sh

LAN_TYPE=$(uci get network.lan.ipaddr | awk -F. ' { print $1"."$2 }')
LEASES_FILE=/tmp/dhcp.leases
lockDir=/tmp/WRTbmon

[ ! -d "$lockDir" ] && mkdir "$lockDir"
basePath="/tmp/bwmon/"
mkdir -p $basePath"data"
dataPath=$basePath"data/"
backPath=/usr/lib/bwmon/data/
mkdir -p "/usr/lib/bwmon/data/"
lockDir1=/tmp/wrtbwmon1.lock
lockDir=/tmp/wrtbwmon.lock
mkdir -p "$lockDir"
pidFile=$lockDir/pid
STARTIMEX=$(date +%s)
STARTIMEY=$(date +%s)
STARTIMEZ=$(date +%s)
cYear=$(date +%Y)
cDay=$(date +%d)
cMonth=$(date +%m)
setup_time=300
update_time=300
backup_time=300
pause=30
unlimited="peak"

networkFuncs=/lib/functions/network.sh
uci=`which uci 2>/dev/null`
nslookup=`which nslookup 2>/dev/null`
nvram=`which nvram 2>/dev/null`
binDir=/usr/sbin
chains='INPUT OUTPUT FORWARD'
DEBUG=
interfaces='eth0' # in addition to detected WAN
DB="/tmp/usage.db"
mode=

log() {
	logger -t "wrtbwmon" "$@"
}

header="#mac,ip,iface,in,out,total,first_date,last_date"

createDbIfMissing()
{
    [ ! -f "$DB" ] && rm -f $DB;echo $header > "$DB"
}

checkWAN()
{
    [ -z "$wan" ] && log "Warning: failed to detect WAN interface."
}

lookup()
{
    MAC=$1
    IP=$2
    userDB=$3
    for USERSFILE in $userDB /tmp/dhcp.leases /tmp/dnsmasq.conf /etc/dnsmasq.conf /etc/hosts; do
	[ -e "$USERSFILE" ] || continue
	case $USERSFILE in
	    /tmp/dhcp.leases )
		USER=$(grep -i "$MAC" $USERSFILE | cut -f4 -s -d' ')
		;;
	    /etc/hosts )
		USER=$(grep "^$IP " $USERSFILE | cut -f2 -s -d' ')
		;;
	    * )
		USER=$(grep -i "$MAC" "$USERSFILE" | cut -f2 -s -d,)
		;;
	esac
	[ "$USER" = "*" ] && USER=
	[ -n "$USER" ] && break
    done
    if [ -n "$DO_RDNS" -a -z "$USER" -a "$IP" != "NA" -a -n "$nslookup" ]; then
	USER=`$nslookup $IP $DNS | awk '!/server can/{if($4){print $4; exit}}' | sed -re 's/[.]$//'`
    fi
    [ -z "$USER" ] && USER=${MAC}
    echo $USER
}

detectIF()
{
    if [ -f "$networkFuncs" ]; then
	IF=`. $networkFuncs; network_get_device netdev $1; echo $netdev`
	[ -n "$IF" ] && echo $IF && return
    fi

    if [ -n "$uci" -a -x "$uci" ]; then
	IF=`$uci get network.${1}.ifname 2>/dev/null`
	[ $? -eq 0 -a -n "$IF" ] && echo $IF && return
    fi

    if [ -n "$nvram" -a -x "$nvram" ]; then
	IF=`$nvram get ${1}_ifname 2>/dev/null`
	[ $? -eq 0 -a -n "$IF" ] && echo $IF && return
    fi
}

detectLAN()
{
    [ -e /sys/class/net/br-lan ] && echo br-lan && return
    lan=$(detectIF lan)
    [ -n "$lan" ] && echo $lan && return
}

detectWAN()
{
    [ -n "$WAN_IF" ] && echo $WAN_IF && return
    wan=$(detectIF wan)
    [ -n "$wan" ] && echo $wan && return
    wan=$(ip route show 2>/dev/null | grep default | sed -re '/^default/ s/default.*dev +([^ ]+).*/\1/')
    [ -n "$wan" ] && echo $wan && return
    [ -f "$networkFuncs" ] && wan=$(. $networkFuncs; network_find_wan wan; echo $wan)
    [ -n "$wan" ] && echo $wan && return
}

lock()
{
    attempts=0
    while [ $attempts -lt 10 ]; do
	mkdir $lockDir1 2>/dev/null && break
	attempts=$((attempts+1))
	pid=`cat $pidFile 2>/dev/null`
	if [ -n "$pid" ]; then
	    if [ -d "/proc/$pid" ]; then
		[ -n "$DEBUG" ] && echo "WARNING: Lockfile detected but process $(cat $pidFile) does not exist !"
		rm -rf $lockDir1
	    else
		sleep 1
	    fi
	fi
    done
    mkdir $lockDir1 2>/dev/null
    echo $$ > $pidFile
    [ -n "$DEBUG" ] && echo $$ "got lock after $attempts attempts"
    trap '' INT
}

unlock()
{
    rm -rf $lockDir1
    [ -n "$DEBUG" ] && echo $$ "released lock"
    trap "rm -f /tmp/*_$$.tmp; kill $$" INT
}

# chain
newChain()
{
    chain=$1
    # Create the RRDIPT_$chain chain (it doesn't matter if it already exists).
    iptables -t mangle -N RRDIPT_$chain 2> /dev/null
    
    # Add the RRDIPT_$chain CHAIN to the $chain chain if not present
    iptables -t mangle -C $chain -j RRDIPT_$chain 2>/dev/null
    if [ $? -ne 0 ]; then
	[ -n "$DEBUG" ] && echo "DEBUG: iptables chain misplaced, recreating it..."
	iptables -t mangle -I $chain -j RRDIPT_$chain
    fi
}

# chain tun
newRuleIF()
{
    chain=$1
    IF=$2
    
    #!@todo test
    if [ "$chain" = "OUTPUT" ]; then
	cmd="iptables -t mangle -o $IF -j RETURN"
	eval $cmd " -C RRDIPT_$chain 2>/dev/null" || eval $cmd " -A RRDIPT_$chain"
    elif [ "$chain" = "INPUT" ]; then
	cmd="iptables -t mangle -i $IF -j RETURN"
	eval $cmd " -C RRDIPT_$chain 2>/dev/null" || eval $cmd " -A RRDIPT_$chain"
    fi
}

setup()
{
	for chain in $chains; do
	    newChain $chain
	done

	wan=$(detectWAN)
	checkWAN
	wan1=$(detectIF wan1)
	wan2=$(detectIF wan2)
	C1=$(uci -q get modem.modem1.connected)
	C2=$(uci -q get modem.modem2.connected)$C1
	if [ ! -z $C2 ]; then
		interfaces="$wan1 $wan2"
	else
		return
	fi

	# track local data
	for chain in INPUT OUTPUT; do
	    for interface in $interfaces; do
		[ -n "$interface" ] && [ -e "/sys/class/net/$interface" ] && newRuleIF $chain $interface
	    done
	done

	# this will add rules for hosts in arp table
	update $dailyUsageDB

	rm -f /tmp/*_$$.tmp
}

update()
{
	createDbIfMissing
    checkWAN

    > /tmp/iptables_$$.tmp
    lock
    # only zero our own chains
    for chain in $chains; do
	iptables -nvxL RRDIPT_$chain -t mangle -Z >> /tmp/iptables_$$.tmp
    done
    # the iptables and readDB commands have to be separate. Otherwise,
    # they will fight over iptables locks
    awk -v mode="$mode" -v interfaces=\""$interfaces"\" -f $binDir/readDB.awk \
	$DB \
	/proc/net/arp \
	/tmp/iptables_$$.tmp
	
	while read L1
	do
	  MAC=$(echo ${L1} | cut -f1 -d, )
	  if [ $MAC != "#mac" ]; then
		MAC=$(echo ${L1} | cut -f1 -d, )
		IP=$(echo ${L1} | cut -f2 -d, )
		IN=$(echo ${L1} | cut -f4 -d, )
		IN=$((${IN}/1000))
		OUT=$(echo ${L1} | cut -f5 -d, )
		OUT=$((${OUT}/1000))
		TOTAL=$(echo ${L1} | cut -f6 -d, )
		TOTAL=$((${TOTAL}/1000))
		if [ $TOTAL -gt 0 -a $IP != "NA" ]; then
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
			if [ -z $NAME ]; then
				NAME="*"
			fi
		
			echo "\"mac\":\""${MAC}"\"","\"down\":\""${IN}"\"","\"up\":\""${OUT}"\"","\"offdown\":\""0"\"","\"offup\":\""0"\"","\"ip\":\""${IP}"\"","\"name\":\""${NAME}"\"" >> ${1}
		fi
	  fi
	done < $DB
		
    unlock
}


createFiles() 
{
	while [ -e /tmplockbw ]; do
		sleep 1
	done
	echo "0" > /tmp/lockbw
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
	rm -f /tmp/lockbw
}

shutDown() 
{
	while [ -e /tmplockbw ]; do
		sleep 1
	done
	echo "0" > /tmp/lockbw
	cp -f $dailyUsageDB $dailyUsageBack 
	cp -f $monthlyUsageDB $monthlyUsageDB".bk"
	echo "start day $cDay" >> $monthlyUsageDB".bk"
	cat "$dailyUsageDB" >> $monthlyUsageDB".bk"
	echo "end day $cDay" >> $monthlyUsageDB".bk"
	cp -f $monthlyUsageDB".bk" $monthlyUsageBack
	rm -f $monthlyUsageDB".bk"
	log "Cleanup backup"
	lua /usr/lib/bwmon/cleanup.lua
	rm -f /tmp/lockbw
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
	while [ -e /tmplockbw ]; do
		sleep 1
	done
	echo "0" > /tmp/lockbw
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
			rm -f $monthlyUsageDB
			rm -f $monthlyUsageBack
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
	rm -f> /tmp/lockbw
}

createFiles
setup
while [ -d $lockDir ]; do
	checkSetup
	checkTime
	#checkUpdate
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
