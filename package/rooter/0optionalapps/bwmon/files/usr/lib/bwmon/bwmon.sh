#!/bin/sh
. /usr/share/libubox/jshn.sh
. /lib/functions.sh

log() {
	modlog "BandWidth Monitor" "$@"
}

createAmt() 
{
	while [ true ]; do
		valid=$(cat /var/state/dnsmasqsec)
		st=$(echo "$valid" | grep "ntpd says time is valid")
		if [ ! -z "$st" ]; then
			break
		fi
		sleep 10
	done
	cYear=$(uci -q get bwmon.backup.year)
	if [ "$cYear" = '0' ]; then # current date
		cYear=$(date +%Y)
		cDay=$(date +%d)
		cMonth=$(date +%m)
		uci set bwmon.backup.year=$cYear
		uci set bwmon.backup.month=$cMonth
		uci set bwmon.backup.day=$cDay
		uci commit bwmon
	else # backup date
		cYear=$(uci -q get bwmon.backup.year)
		cMonth=$(uci -q get bwmon.backup.month)
		cDay=$(uci -q get bwmon.backup.day)
	fi
	# load totals from backup
	basedailytotal=$(uci -q get bwmon.backup.dailytotal)
	if [ -z "$basedailytotal" ]; then
		basedailytotal='0'
	fi
	basedailyrx=$(uci -q get bwmon.backup.dailyrx)
	if [ -z "$basedailyrx" ]; then
		basedailyrx='0'
	fi
	basedailytx=$(uci -q get bwmon.backup.dailytx)
	if [ -z "$basedailytx" ]; then
		basedailytx='0'
	fi
	basemontotal=$(uci -q get bwmon.backup.montotal)
	if [ -z "$basemontotal" ]; then
		basemontotal='0'
	fi
	basemonrx=$(uci -q get bwmon.backup.monrx)
	if [ -z "$basemonrx" ]; then
		basemonrx='0'
	fi
	basemontx=$(uci -q get bwmon.backup.montx)
	if [ -z "$basemontx" ]; then
		basemontx='0'
	fi
	
	dailyoffsettotal=0
	dailyoffsetrx=0
	dailyoffsettx=0
	monoffsettotal=0
	monoffsetrx=0
	monoffsettx=0
	offsettot=0
	offsetrx=0
	offsettx=0
}

device_get_stats() {
	iface=$1
	st=$(ubus -v call network.interface.$iface status)
	json_init
	json_load "$st"
	json_get_var iface l3_device
	json_get_var status up
	if [ $status = "1" ]; then
		js="{ \"name\": \"$iface\" }"
		st=$(ubus -v call network.device status "$js")
		json_init
		json_load "$st"
		json_select statistics &>/dev/null
		json_get_var val $2
	else
		val="0"
	fi
	echo $val
}

update() {
	interfaces="wan1 wan2 wan wwan2 wwan5"
	
	rxval="0"
	txval="0"
	for interface in $interfaces; do
		rval=$(device_get_stats $interface "rx_bytes")
		let rxval=$rxval+$rval
		tval=$(device_get_stats $interface "tx_bytes")
		let txval=$txval+$tval
	done
	let totval=$rxval+$txval
	# current day totals
#	log "Raw Daily $totval $txval $rxval"
	let currdailytotal=$totval-$dailyoffsettotal+$basedailytotal
	let currdailyrx=$rxval-$dailyoffsetrx+$basedailyrx
	let currdailytx=$txval-$dailyoffsettx+$basedailytx
	let cdailytotal=$totval+$basedailytotal
	let cdailyrx=$rxval+$basedailyrx
	let cdailytx=$txval+$basedailytx
#	log "Full Daily $cdailytotal $cdailytx $cdailyrx"
#	log "Current Daily $currdailytotal $currdailytx $currdailyrx"
#	log "Daily Offset $dailyoffsettotal $dailyoffsettx $dailyoffsetrx"
#	log " "
	# current month totals
	let currmontotal=$totval-$monoffsettotal+$basemontotal
	let currmonrx=$rxval-$monoffsetrx+$basemonrx
	let currmontx=$txval-$monoffsettx+$basemontx
	#log "Current Monthly $currmontotal $currmontx $currmonrx"
	#echo "Update Monthly $monoffsettotal $monoffsettx $monoffsetrx"
	# values in bytes
	
	alloc=$(uci -q get custom.bwallocate.allocate)
	if [ -z "$alloc" ]; then
		alloc=1000000000
	else
		alloc=$alloc"000000000"
	fi
	/usr/lib/bwmon/excede.sh $currmontotal $alloc
	
}

checkTime() 
{
	pDay=$(date +%d)
	pYear=$(date +%Y)
	pMonth=$(date +%m)
#pDay=$(uci -q get bwmon.backup.tday)
	if [ "$cDay" -ne "$pDay" ]; then # day change
	
		# save as daily totals
#log "Daily Amt Saved $currdailytotal $currdailytx $currdailyrx"
		echo "$currdailytotal" > $dataPath"daily.js"
		echo "$currdailytx" >> $dataPath"daily.js"
		echo "$currdailyrx" >> $dataPath"daily.js"
		cd=$cDay
		if [ $cd -lt 10 ]; then
			ct="0"$cd
		fi
		dt="$cYear-$cMonth-$cd"
		echo "$dt" >> $dataPath"daily.js"
		/usr/lib/bwmon/createdata.lua
		
		bt=$(uci -q get custom.bwday)
		if [ -z "$bt" ]; then
			uci set custom.bwday='bwday'
		fi
		uci set custom.bwday.bwday=$(convert_bytes $mtotal)
		uci commit custom
		bwday=$(uci -q get modem.modeminfo1.bwday)
		if [ ! -z "$bwday" ]; then
			if [ $bwday = $pDay -a $bwday != "0" ]; then
				if [ -e /usr/lib/bwmon/sendsms ]; then
					/usr/lib/bwmon/sendsms.sh &
				fi
			fi
		fi
		
		cDay=$pDay
		cMonth=$pMonth
		cYear=$pYear
		basedailytotal=0
		basedailyrx=0
		basedailytx=0
		let dailyoffsettotal=$totval
		let dailyoffsetrx=$rxval
		let dailyoffsettx=$txval
		roll=$(uci -q get custom.bwallocate.rollover)
		[ -z $roll ] && roll=1
		if [ "$roll" -le "$pDay" ]; then # new month
			basemontotal=0
			basemonrx=0
			basemontx=0
			let monoffsettotal=$totval
			let monoffsetrx=$rxval
			let monoffsettx=$txval
			uci set custom.texting.used="0"
			uci set custom.bwallocate.persent="0"
			uci commit custom
#log "Last Month $currmontotal $currmonrx $currmontx"
		fi
		# increase days
		days=$(uci -q get bwmon.backup.days)
		let days=$days+1
		uci set bwmon.backup.days=$days
		uci set bwmon.backup.year=$pYear
		uci set bwmon.backup.month=$pMonth
		uci set bwmon.backup.day=$pDay
		uci commit bwmon
	fi
}

checkBackup() 
{
	CURRTIME=$(date +%s)
	let ELAPSE=CURRTIME-BSTARTIME
	
	bs=$(uci -q get bwmon.general.backup)
	let "bs=$bs*60"
	backup_time=$bs
	en=$(uci -q get bwmon.general.enabled)
	if [ "$en" = '1' ]; then
		if [ $ELAPSE -gt $backup_time ]; then
			BSTARTIME=$CURRTIME
#log "Backup"
			uci set bwmon.backup.dailytotal=$currdailytotal
			uci set bwmon.backup.dailyrx=$currdailyrx
			uci set bwmon.backup.dailytx=$currdailytx
			uci set bwmon.backup.montotal=$currmontotal
			uci set bwmon.backup.monrx=$currmonrx
			uci set bwmon.backup.montx=$currmontx
			uci set bwmon.backup.year=$cYear
			uci set bwmon.backup.month=$cMonth
			uci set bwmon.backup.day=$cDay
			uci commit bwmon
		fi
	fi
}

convert_bytes() {
	local val=$1
	rm -f /tmp/bytes
	if [ ! -z "$val" ]; then
		/usr/lib/bwmon/convertbytes.lua $val
		source /tmp/bytes
	else
		BYTES=0
	fi
	echo "$BYTES"
}

createGUI()
{
	days=$(uci -q get bwmon.backup.days)
	echo "$days" > /tmp/bwdata
	tb=$(convert_bytes $currmontotal)
	echo "$currmontotal" >> /tmp/bwdata
	echo "$tb" >> /tmp/bwdata
	tb=$(convert_bytes $currmonrx)
	echo "$currmonrx" >> /tmp/bwdata
	echo "$tb" >> /tmp/bwdata
	tb=$(convert_bytes $currmontx)
	echo "$currmontx" >> /tmp/bwdata
	echo "$tb" >> /tmp/bwdata
	let ptotal=$currmontotal/$days
	let ptotal=$ptotal*30
	tb=$(convert_bytes $ptotal)
	echo "$ptotal" >> /tmp/bwdata
	echo "$tb" >> /tmp/bwdata
	alloc=$(uci -q get custom.bwallocate.allocate)
	pass=$(uci -q get custom.bwallocate.password)
	if [ -z "$alloc" ]; then
		alloc=1000000000
		pass="password"
	else
		alloc=$alloc"000000000"
		pass="password"
	fi
	tb=$(convert_bytes $alloc)
	echo "$alloc" >> /tmp/bwdata
	echo "$tb" >> /tmp/bwdata
	echo "$pass" >> /tmp/bwdata
	echo "0" >> /tmp/bwdata
}

basePath="/tmp/bwmon/"
mkdir -p $basePath"bwdata"
dataPath=$basePath"bwdata/"
STARTIME=$(date +%s)
BSTARTIME=$STARTIME
update_time=10 # check each seconds

createAmt
while [ true ] ; do
	update
	checkTime
	checkBackup
	createGUI
	sleep $update_time
done