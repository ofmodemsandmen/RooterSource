#!/bin/sh

##########################################################################
#
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
##########################################################################

#HISTORY

# 3.4.0 (2018-02-04): first release of 3.4... added better support for bridged devices, fixed multiple ips per mac; numerous other changes & fixes
# 3.4.1 (2018-02-10): fixed local ips; improved alert.js; reports on monthly usage vs cap
# 3.4.3 (2018-03-10): numerous fixes and firmware compatibility issues
# 3.4.4 (2018-03-12): re-added _path2ip; fixed null issues in clearDupIPs & checkIPs; recreate router.js if null; fixed totMem
# 3.4.4b (2018-03-28): replaced sed -E with sed -r
# 3.4.4c (2018-04-02): updated check for old duplicate IPs marked with x/y
# 3.4.5 (2018-04-02): added _local_ip6, cleaned up lots of log2file entries; added bytes & unknown to conntrack data; cleanup up iptables -L to -nL, removed unused getForwardData
# 3.4.6 (2018-08-11): added option to exclude failed/incomplete entries; check static leases on launch; detach from terminal
# 3.4.6a (2019-01-25): added check for firmware in updateStaticLeases()	
# 3.4.6b (2019-01-26): suppressed the error output from crippled ip function; fixed owner replacement in updateStaticLeases()
# 3.4.7 (2019-01-29): fixed lingering _updated_ in users.js; better handling of cripple ip function for IPv6

# ==========================================================
#				  Functions
# ==========================================================
setupIPChains(){
	$send2log "setupIPChains ($cmd/$rule/$_includeIPv6)" 0
	ip6chains_0()
	{	#_includeIPv6=0
		$send2log "ip6chains_0" 0
		return
	}
	ip6chains_1()
	{	#_includeIPv6=1
		$send2log "ip6chains_1" 0
        ipchains=$(eval ip6tables $_tMangleOption -nL -vx | grep Chain)
        checkChain 'ip6tables' "$YAMON_IP6"
        checkChain 'ip6tables' "${YAMON_IP6}Entry"
        checkChain 'ip6tables' "${YAMON_IP6}Local"

        addLocalBlocks 'ip6tables' "$YAMON_IP6" "$_PRIVATE_IP6_BLOCKS" "$_generic_ipv6"
    
		checkIPChain 'ip6tables' 'FORWARD' "$YAMON_IP6"
		checkIPChain 'ip6tables' 'INPUT' "$YAMON_IP6"
		checkIPChain 'ip6tables' 'OUTPUT' "$YAMON_IP6"
	}
    checkChain(){
		$send2log "checkChain:  $1  $2" 0
		local cmd="$1"
        local chain="$2"
        local ce=$(echo "$ipchains" | grep "$chain\b")
        if [ -z "$ce" ] ; then
            $send2log "Adding $chain in $cmd ($_tMangleOption)" 2
            eval $cmd $_tMangleOption -N $chain
        else 
            $send2log "$chain exists in $cmd ($_tMangleOption)" 0
        fi
    }
    addLocalBlocks(){
		$send2log "addLocalBlocks:  $1  $2  $3  $4" 0
        local cmd="$1"
        local chain="$2"
        local ip_blocks="$3"
        local generic="$4"
        eval $cmd $_tMangleOption -F "$chain"
        eval $cmd $_tMangleOption -F "${chain}Entry"
        eval $cmd $_tMangleOption -F "${chain}Local"
    	IFS=$','
        for iprs in $ip_blocks
        do
            for iprd in $ip_blocks
            do
                if [ "$cmd" == 'iptables' ] ; then
					eval $cmd $_tMangleOption -I "${chain}Entry" -g "${chain}Local" -s $iprs -d $iprd
				else
					eval $cmd $_tMangleOption -I "${chain}Entry" -j "RETURN" -s $iprs -d $iprd
					eval $cmd $_tMangleOption -I "${chain}Entry" -j "${chain}Local" -s $iprs -d $iprd
				fi
            done
        done
        eval $cmd $_tMangleOption -A "${chain}Entry" -j "${chain}"
        eval $cmd $_tMangleOption -I "${chain}Local" -j "RETURN" -s $generic -d $generic
        #[ "$cmd" == 'iptables' ] && eval $cmd $_tMangleOption -A "$chain" -g "${chain}_gp_Unknown" -s $generic -d $generic
        unset IFS
		$send2log "chains --> $cmd / $chain
$(eval $cmd $_tMangleOption -nL -vx | grep $chain | grep Chain)" 0

    }
    addLocalIPs(){
		$send2log "addLocalIPs:  $1  $2  $3  $4" 0
        local cmd="$1"
        local chain="$2"
        local ip_addresses="$3"
        local generic="$4"
    	IFS=$','
        for ip in $ip_addresses
        do
			eval $cmd $_tMangleOption -I "${chain}Entry" -g "${chain}Local" -s $ip -d $generic
			eval $cmd $_tMangleOption -I "${chain}Entry" -g "${chain}Local" -s $generic -d $ip		
        done
        unset IFS
    }
	
	ipchains=$(eval iptables $_tMangleOption -nL -vx | grep Chain)
    checkChain 'iptables' "$YAMON_IP4"
    checkChain 'iptables' "${YAMON_IP4}Entry"
    checkChain 'iptables' "${YAMON_IP4}Local"

    addLocalBlocks 'iptables' "$YAMON_IP4" "$_PRIVATE_IP4_BLOCKS" "$_generic_ipv4" 
    addLocalIPs 'iptables' "$YAMON_IP4" "$_LOCAL_IP4" "$_generic_ipv4" 
    
	checkIPChain "iptables" "FORWARD" "$YAMON_IP4"
	checkIPChain "iptables" "INPUT" "$YAMON_IP4"
	checkIPChain "iptables" "OUTPUT" "$YAMON_IP4"
	eval "ip6chains_"$_includeIPv6
}
setInitValues(){

	_configFile="$d_baseDir/config.file"
	source "$_configFile"
	loadconfig
	$(ip -6 neigh show >> /tmp/ipv6.text 2>&1)
	if [ $? -ne 0 ] ; then
		_includeIPv6=0
		echo "  
*** _includeIPv6 changed to 0 because the installed version of the ip function
    does not support IPv6 or the neigh parameter.
*** Please check your config.file and/or your version of busybox.
" >&2 
	fi
	rm /tmp/ipv6.text
	source "$d_baseDir/strings/$_lang/strings.sh"
	setLogFile

	setFirmware
	setupIPChains
    
	local sortStr=''
	if [ -z "$(which sort)" ] || [ -z "$(which uniq)" ] ; then
		hasUniq=0
		tallyHourlyData="tallyHourlyData_0"
	else
		sortStr=" | sort -k2"
		hasUniq=1
		tallyHourlyData="tallyHourlyData_1"
	fi
	updateServerStats
	setDataDirectories
	setWebDirectories
	setUsers
	setConfigJS
	[ ! -d "$_lockDir" ] && mkdir "$_lockDir"
	local ts=$(date +"%H:%M:%S")
	if [ "$started" -eq "0" ] ; then
		echo "$_s_started"
		if [ "$_doLocalFiles" -gt "0" ] ; then
			source "$d_baseDir/includes/getLocalCopies.sh"
			getLocalCopies
		fi
		$send2log "YAMon was started" 99
	fi
	meminfo=$(cat /proc/meminfo | tr -s ' ')
	_totMem=$(getMI "MemTotal")
	$send2log "_totMem: $_totMem" 0

	local iginc=' grep -v '00:00:00:00:00:00' | '
	[ "$_includeIncomplete" -eq "1" ] && iginc=''
	
	[ -z "$_path2ip" ] && _path2ip=$(which ip)
	if [ "$_firmware" -eq "4" ] ; then
		_getIP4List="cat /proc/net/arp | grep '^[0-9]' | $iginc tr -s ' ' | cut -d' ' -f1,4 | tr 'A-Z' 'a-z' $sortStr"

	else
		$($_path2ip -4 neigh show >> /tmp/ipv4.text 2>&1)
		if [ $? -eq 0 ] ; then
			$send2log  "Using ip to detect active IP/MAC combinations" 1
			_getIP4List="$_path2ip -4 neigh | cut -d' ' -f1,5 | tr 'A-Z' 'a-z' $sortStr"
		else
			_getIP4List="cat /proc/net/arp | grep '^[0-9]' | $iginc tr -s ' ' | cut -d' ' -f1,4 | tr 'A-Z' 'a-z' $sortStr"
			$send2log  "Using arp to detect active IP/MAC combinations" 1
		fi
		rm  '/tmp/ipv4.text'

	fi
	$send2log "_getIP4List-->$_getIP4List" 0

	if [ "$_includeIPv6" -eq "1" ] ; then
		_local_ip6=${_local_ip6//,/|}
		_getIP6List="$_path2ip -6 neigh | grep -Evi \"$_local_ip6\" | cut -d' ' -f1,5 | tr 'A-Z' 'a-z' $sortStr" 
		$send2log "_getIP6List-->$_getIP6List" 0
		$send2log "_local_ip6-->$_local_ip6" 0
	fi
	_usersLastMod=$(date -r "$_usersFile" "+%Y-%d-%m %T")
	started=1
}
setLogFile()
{
#
# ROOter
#
	if [ $_enableLogging -ne 0 ]; then
#
		if [ "${_logDir:0:1}" == "/" ] ; then
			local lfpath=$_logDir
		else
			local lfpath="${d_baseDir}/$_logDir"
		fi
		lfpath=${lfpath//\/\//\/}
		[ ! -d "$lfpath" ] && mkdir -p "$lfpath"
		_logfilename="${lfpath}monitor$_version-$_cYear-$_cMonth-$_cDay.log"
		[ ! -d "$$_wwwPath${_wwwJS}" ] && mkdir -p "$_wwwPath${_wwwJS}"
		_alertfilename="$_wwwPath${_wwwJS}alerts.js"

		[ ! -f "$_logfilename" ] && touch "$_logfilename"
		if [ ! -f "$_alertfilename" ] ; then
			touch $_alertfilename
			$send2log "Created $_alertfilename" 0
		fi
		$send2log "YAMon:: version $_version	_loglevel: $_loglevel" 1
		$send2log "setLogFile" 0
		$send2log "Installed firmware: $installedfirmware $installedversion $installedtype" 1
		$send2log "_logfilename-->$_logfilename" 1
#
# ROOter
#
	fi
#
}
setDataDirectories()
{
	$send2log "setDataDirectories" 0
	local rMonth=${_cMonth#0}
	local rYear="$_cYear"
	local rday=$(printf %02d $_ispBillingDay)
	if [ "$_cDay" -lt "$_ispBillingDay" ] ; then
		rMonth=$(($rMonth-1))
		if [ "$rMonth" == "0" ] ; then
			rMonth=12
			rYear=$(($rYear-1))
		fi
	fi
	
	rMonth=$(printf %02d $rMonth)
	if [ "${_dataDir:0:1}" == "/" ] ; then
		_dataPath=$_dataDir
	else
		_dataPath="${d_baseDir}/$_dataDir"
	fi
	$send2log ">>> _dataPath --> $_dataPath" 0
	if [ ! -d "$_dataPath" ] ; then
		$send2log ">>> Creating data directory" 0
		mkdir -p "$_dataPath"
		chmod -R 666 "$_dataPath"
	fi
	case $_organizeData in
		(*"0"*)
			local savePath="$_dataPath"
			local wwwsavePath="$_wwwPath$_wwwData"
		;;
		(*"1"*)
			local savePath="$_dataPath$rYear/"
			local wwwsavePath="$_wwwPath$_wwwData$rYear/"
		;;
		(*"2"*)
			local savePath="$_dataPath$rYear/$rMonth/"
			local wwwsavePath="$_wwwPath$_wwwData$rYear/$rMonth/"
		;;
	esac
	
	savePath=${savePath//\/\//\/}
	wwwsavePath=${wwwsavePath//\/\//\/}
	
	if [ ! -d "$savePath" ] ; then
		$send2log ">>> Adding data directory - $savePath " 0
		mkdir -p "$savePath"
		chmod -R 666 "$savePath"
	else
		$send2log ">>> data directory exists - $savePath " -1
	fi
	if [ "$_symlink2data" -eq "0" ] && [ ! -d "$wwwsavePath" ] ; then
		$send2log ">>> Adding web directory - $wwwsavePath " 0
		mkdir -p "$wwwsavePath"
		chmod -R 666 "$wwwsavePath"
	else
		$send2log ">>> web directory exists - $wwwsavePath " -1
	fi

	[ "$(ls -A $_dataPath)" ] && $copyfiles "$_dataPath*" "$_wwwPath$_wwwData"
	_macUsageDB="$savePath$rYear-$rMonth-$_usageFileName"
	_macUsageWWW="$wwwsavePath$rYear-$rMonth-$rday-$_usageFileName"
	local old_macUsageDB="$savePath$rYear-$rMonth-$rday-$_usageFileName"
	if [ -f "$_macUsageDB" ] ; then
		$send2log "_macUsageDB exists--> $_macUsageDB" 1
	elif [ -f "$old_macUsageDB" ] ; then
		$send2log "copying $old_macUsageDB --> $_macUsageDB" 1
		$(cp -a $old_macUsageDB $_macUsageDB)
	else
		createMonthlyFile
	fi
	
	[ ! -d "$_wwwPath$_wwwJS" ] && mkdir -p "$_wwwPath$_wwwJS"
	
	[ "$_doLiveUpdates" -eq "1" ] && _liveFilePath="$_wwwPath$_wwwJS$_liveFileName"
	[ "$_doArchiveLiveUpdates" -eq "1" ] && _liveArchiveFilePath="$wwwsavePath$_cYear-$_cMonth-$_cDay-$_liveFileName"
	
	_hourlyUsageDB="$savePath$_cYear-$_cMonth-$_cDay-$_hourlyFileName"
	_hourlyUsageWWW="$wwwsavePath$_cYear-$_cMonth-$_cDay-$_hourlyFileName"

	[ ! -f "$_hourlyUsageDB" ] && createHourlyFile
	local hd=$(cat "$_hourlyUsageDB")
	local hdhu=$(echo "$hd" | grep '^hu' )
	local hdpd=$(echo "$hd" | grep '^pnd' )
	_hourlyCreated=$(echo "$hd" | grep '^var hourly_created')
	local hr=$(date +"%H")
	_hourlyData=$(echo "$hdhu" | grep -v "\"hour\":\"$hr\"")
	_thisHrdata=$(echo "$hdhu" | grep "\"hour\":\"$hr\"")
	_pndData=$(echo "$hdpd" | grep -v "\"hour\":\"$hr\"")
	_thisHrpnd=$(echo "$hdpd" | grep "\"hour\":\"$hr\"")
	$send2log "_hourlyData--> $_hourlyData" -1
	$send2log "_thisHrdata ($hr)--> $_thisHrdata" 0
	$send2log "_pndData--> $_pndData" -1
	$send2log "_thisHrpnd ($hr)--> $_thisHrpnd" 0
	
	routerfile="${d_baseDir}/${_webDir}/${_wwwJS}/router.js"
	routerfile=${routerfile//\/\//\/}
	[ -f "$routerfile" ] && return
	
	$send2log "recreated $routerfile" 2
	local installed=$(date +"%Y-%m-%d %H:%M:%S")
	local updated=''
	local routermodel='Unknown'
	local installedfirmware=''
	local installedversion=''
	local installedtype=''
		
	if [ -f "/etc/openwrt_release" ] ; then
		installedfirmware=$(cat /etc/openwrt_release | grep -i 'DISTRIB_DESCRIPTION' | cut -d"'" -f2)
	elif [ "$_firmware" -eq "2" ] ; then
		routermodel=$(nvram get model)
		installedversion=$(nvram get buildno)_$(nvram get extendno)
		installedtype='merlin'
	elif [ "$_has_nvram" -eq "1" ] ; then
		installedfirmware=$(uname -o)
		routermodel=$(nvram get DD_BOARD)
		installedversion=$(nvram get os_version)
		installedtype=$(nvram get dist_type)
	fi
	if [ -d /tmp/sysinfo/ ] ; then
		local model=$(cat /tmp/sysinfo/model)
		local board=$(cat /tmp/sysinfo/board_name)
		routermodel="$model $board"
	fi
	
	echo "var installed='$installed'
var updated='$updated'
var router='$routermodel'
var firmware='$installedfirmware $installedversion $installedtype'
var version='$_version'" > $routerfile

}
createMonthlyFile()
{
	$send2log "createMonthlyFile" 0
	$send2log ">>> Monthly usage file not found... creating new file: $_macUsageDB" 2
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	touch $_macUsageDB
	chmod 666 $_macUsageDB
	local nmf="var monthly_created=\"$ds\"
var monthly_updated=\"$ds\"
var monthlyDataCap=\"$_monthlyDataCap\""
	$save2File "$nmf" "$_macUsageDB"
	$copyfiles "$_macUsageDB" "$_macUsageWWW"
}
createHourlyFile()
{
	$send2log "createHourlyFile" 0
	touch $_hourlyUsageDB
	chmod 666 $_hourlyUsageDB
	$send2log ">>> Hourly usage file not found... creating new file: $_hourlyUsageDB" 2
	$doliveUpdates
	local upsec=$(cat /proc/uptime | cut -d' ' -f1)
	local ds=$(date +"%Y-%m-%d %H:%M:%S")

	local hc="var hourly_created=\"$ds\""
	_pndData=$(getStartPND 'start' "$upsec")
	local hourlyHeader=$(getHourlyHeader "$upsec" "$ds")
	_hourlyData=''
	local nht="$_hourlyCreated
$hourlyHeader

$_pndData"
	$save2File "$nht" "$_hourlyUsageDB"
	$copyfiles "$_hourlyUsageDB" "$_hourlyUsageWWW"

}
getMI()
{
	local result=$(echo "$meminfo" | grep -i "^$1:" | cut -d' ' -f2)
	[ -z "$result" ] && result=0
	echo "$result"
	$send2log "getMI: $1=$result" 0
}
	
getHourlyHeader(){
	$send2log "getHourlyHeader:  $1  $2" 0
	meminfo=$(cat /proc/meminfo | tr -s ' ')
	local freeMem=$(getMI "MemFree")
	local bufferMem=$(getMI "Buffers")
	local cacheMem=$(getMI "Cached")
	local availMem=$(($freeMem+$bufferMem+$cacheMem))
	local disk_utilization=$(df "${d_baseDir}" | tail -n 1 | tr -s ' ' | cut -d' ' -f5)

	echo "
var hourly_updated=\"$2\"
var users_updated=\"$_usersLastMod\"
var disk_utilization=\"$disk_utilization\"
var serverUptime=\"$1\"
var freeMem=\"$freeMem\",availMem=\"$availMem\",totMem=\"$_totMem\"
serverloads(\"$sl_min\",\"$sl_min_ts\",\"$sl_max\",\"$sl_max_ts\")

"
}
getStartPND(){
	$send2log "getStartPND: $1" 0
	local thr="$1"
	$send2log "*** setting start in pnd - $_br_d / $_br_u" 1
	if [ -z "$_br_d" ] || [ -z "$_br_u" ] ; then
		local tstr=$(getPND "$thr" "$upsec")
		_br_u=$(getCV "$tstr" 'up')
		_br_d=$(getCV "$tstr" 'down')
	fi
	$send2log "*** getStartPND: _br_d: $_br_d  _br_u: $_br_u" -1
	local result="pnd({\"hour\":\"$thr\",\"uptime\":$2,\"down\":$_br_d,\"up\":$_br_u,\"lost\":$_totalLostBytes,\"hr-loads\":\"$hr_min1,$hr_min5,$hr_max5,$hr_max1\"})"
	echo "$result"
	$send2log "result-->$result" -1
}
getPND(){
	$send2log "getPND: $1" 0
	local thr="$1"
	local br0=$(cat "/proc/net/dev" | grep -i "$_lan_iface" | tr -s ': ' ' ')
	$send2log "*** PND: br0: [$br0]" -1
	local br_d=$(echo $br0 | cut -d' ' -f10)
	local br_u=$(echo $br0 | cut -d' ' -f2)
	[ "$br_d" == '0' ] && br_d=$(echo $br0 | cut -d' ' -f11)
	[ "$br_u" == '0' ] && br_u=$(echo $br0 | cut -d' ' -f3)
	[ -z "$br_d" ] && br_d=0
	[ -z "$br_u" ] && br_u=0
	$send2log "*** PND: br_d: $br_d  br_u: $br_u" -1
	local result="pnd({\"hour\":\"$thr\",\"uptime\":$2,\"down\":$br_d,\"up\":$br_u,\"lost\":$_totalLostBytes,\"hr-loads\":\"$hr_min1,$hr_min5,$hr_max5,$hr_max1\"})"
	echo "$result"
	$send2log "result-->$result" -1
}
setUsers(){
	fixIncompletes()
	{
		local gplist="$(cat $_usersFile | grep -i "in:co:mp:le:te-\d\b")"
		IFS=$'\n'
		for lline in $gplist
		do
			local mac=$(getField "$lline" 'mac')
			local m=$(echo "$mac" | cut -d- -f1)
			local n=$(printf %02d $(echo "$mac" | cut -d- -f2) )
			_currentUsers=$(echo "$_currentUsers" | sed -e "s~$mac\b~$m-$n~Ig")
			_changesInUsersJS=$(($_changesInUsersJS + 1))
		done
	}
	
	getGroups_0()
	{ #for firmware without sort/uniq
		local gplist="$(cat $_usersFile | grep -o \"owner\":\"[^\"]*\" | cut -d: -f2 | sed "s~[^a-z0-9]~~ig")"
		local retlist=''
		IFS=$'\n'
		for lline in $gplist
		do
			local gp=${lline//\"/}
			if [ -z "$(echo $retlist | grep $gp)" ] ;  then
				retlist="$gp
$retlist"
			fi
		done
		echo "$retlist"
	}
	
	getGroups_1()
	{ #for firmware with sort/uniq
		echo "$(cat $_usersFile | grep -o \"owner\":\"[^\"]*\" | cut -d: -f2 | sort | uniq | sed "s~[^a-z0-9]~~ig")"
	}
	
	$send2log "setUsers" 0
	_usersFile="$_dataPath$_usersFileName"
	[ "$_symlink2data" -eq "0" ] && _usersFileWWW="$_wwwPath$_wwwData$_usersFileName"
	[ ! -f "$_usersFile" ] && createUsersFile
	_currentUsers=$(cat "$_usersFile" | sed -e "s~(dup) (dup)~(dup)~Ig" | sed -e "s~0.0.0.0_0~0.0.0.0\/0~Ig")
	
	fixIncompletes	
	
	local groups=$(eval "getGroups_$hasUniq")
	local gpchains=$(eval iptables $_tMangleOption -nL -vx | grep "${YAMON_IP4}_gp_")
	IFS=$'\n'
	for group in $groups
	do
		[ -z "$group" ] && continue;
		local gc="${YAMON_IP4}_gp_$group"
        local ce=$(echo "$gpchains" | grep "$group\b")
        if [ -z "$ce" ] ; then
            $send2log "Adding group chain to iptables: $gc  " 2
            eval iptables $_tMangleOption -N "$gc"
			eval iptables $_tMangleOption -A "$gc" -j "RETURN" -s $_generic_ipv4 -d $_generic_ipv4
        else 
            $send2log "Group chain $gc exists in iptables" 0
        fi
   	done
	unset IFS

	ifcl=$(ifconfig | grep HWaddr | tr -s ' ' |  cut -d ' ' -f1,5)
	$send2log "ifcl: $ifcl" -1
	IFS=$'\n'
	for line in $ifcl
	do
		[ -z "$line" ] && continue
		f1=$(echo "$line" | cut -d' ' -f1)
		mac=$(echo "$line" | cut -d' ' -f2 | tr 'A-Z' 'a-z')
		ip4=$(ifconfig $f1 | grep 'inet addr' | tr -s ' ' | cut -d' ' -f3 | sed "s~addr:~~ig")
		$send2log "line: $line" -1
		if [ -n "$ip4" ] ; then
			$send2log "$ip4 / $mac" -1
			checkIPTableEntries "iptables" "$YAMON_IP4" "$ip4" "$mac"
			CheckUsersJS $mac $ip4 0 "Hardware" "$f1" 1
		fi
		if [ "$_includeIPv6" -eq "1" ] ; then
			ip6=$(ifconfig $f1 | grep 'inet6' | grep -Ev "$_local_ip6" | tr -s ' ' | cut -d' ' -f4 | cut -d/ -f1)
			ipl=''
			comma=''
			$send2log "ip6: $ip6" -1
			for ips in $ip6
			do
				$send2log "$ips / $mac" 0
				[ -z "$(echo "$ips" | grep -Ei "$_local_ip6")" ] && checkIPTableEntries "ip6tables" "$YAMON_IP6" "$ips" "$mac"
				ipl="$ipl$comma$ips"
				comma=','
			done
			[ -n "$ipl" ] && CheckUsersJS $mac $ipl 1 "Hardware" "$f1" 1
		fi
	done
		
	if [ -n "$_lan_ipaddr" ] ; then
		local lipe=$(echo "$_currentUsers" | grep -i "\b$_lan_hwaddr\b")
		[ -z "$lipe" ] && CheckUsersJS $_lan_hwaddr $_lan_ipaddr 0 "Hardware" "LAN MAC"
	fi
	
	if [ -n "$_wan_ipaddr" ] ; then
		lipe=$(echo "$_currentUsers" | grep -i "\b$_wan_hwaddr\b")
		[ -z "$lipe" ] && [ "$_wan_hwaddr" != "$_lan_hwaddr" ] && CheckUsersJS $_wan_hwaddr $_wan_ipaddr 0 "Hardware" "WAN MAC"
	fi
	lipe=$(echo "$_currentUsers" | grep "\b$_generic_ipv4\b")
	[ -z "$lipe" ] && CheckUsersJS $_generic_mac $_generic_ipv4 0 "Unknown" "No Matching MAC"

	$send2log "$_generic_ipv4 / $_generic_mac" 0
	checkIPTableEntries "iptables" "$YAMON_IP4" "$_generic_ipv4" "$_generic_mac"
	
	if [ -n "$_lan_ipaddr" ] ; then
		$send2log "$_lan_ipaddr / $_lan_hwaddr" 0
		checkIPTableEntries "iptables" "$YAMON_IP4" "$_lan_ipaddr" "$_lan_hwaddr"
	fi
	if [ -n "$_wan_ipaddr" ] ; then
		$send2log "$_wan_ipaddr / $_wan_hwaddr" 0
		checkIPTableEntries "iptables" "$YAMON_IP4" "$_wan_ipaddr" "$_wan_hwaddr"
	fi

	if [ "$_includeIPv6" -eq "1" ] ; then
		mline=$(echo "$_currentUsers" | grep "[\b\"]$_generic_ipv6\b")
		[ -z "$mline" ] && CheckUsersJS $_generic_mac $_generic_ipv6 1

		local gp6chains=$(eval ip6tables $_tMangleOption -nL -vx | grep "${YAMON_IP6}_gp_")
		IFS=$'\n'
		for group in $groups
		do
			[ -z "$group" ] && continue;
			local gc="${YAMON_IP6}_gp_$group"
			local ce=$(echo "$gp6chains" | grep "$group\b")
			if [ -z "$ce" ] ; then
				$send2log "Adding group chain to ip6tables: $gc  " 2
				eval ip6tables $_tMangleOption -N "$gc"
				eval ip6tables $_tMangleOption -A "$gc" -j "RETURN" -s $_generic_ipv6 -d $_generic_ipv6

			else 
				$send2log "Group chain $gc exists in ip6tables" 0
			fi
		done
		unset IFS
		$send2log "$_generic_ipv6 / $_generic_mac" 0
		checkIPTableEntries "ip6tables" "$YAMON_IP6" "$_generic_ipv6" "$_generic_mac"
		[ -n "$_lan_ip6addr" ] && [ -z "$(echo "$_lan_ip6addr" | grep -Ei "$_local_ip6")" ] && checkIPTableEntries "ip6tables" "$YAMON_IP6" "$_lan_ip6addr" "$_lan_hwaddr"
	fi
	
	$send2log "started-->$started  _includeIPv6-->$_includeIPv6  " -1
	[ "$started" -eq "0" ] && checkUsers4IP
	$send2log "_currentUsers -->
$_currentUsers" -1

	IFS=$'\n'
	local device_list=$(echo "$_currentUsers" | grep -e "^ud_a")
	for device in $device_list
	do
		$send2log "device: $device" 0
		ip4=$(getField "$device" 'ip')
		mac=$(getField "$device" 'mac')
		owner=$(getField "$device" 'owner')
		name=$(getField "$device" 'name')
		IFS=$','
		for ip in $ip4
		do
			[ -z "$(echo "$ip" | grep '(dup)')" ] || continue
			wip='ip'
			if [ -n "$(echo "${ip:0:1}" | grep -i "[xy]")" ] ; then
				o_ip="$ip"
				ip="${ip:1} (dup)"
				tip=${ip//\./\\.}
				mline="$device"
				updateinUsersJS
				IFS=$','
			fi
			checkIPTableEntries "iptables" "$YAMON_IP4" "$ip" "$mac"
			CheckUsersJS $mac "$ip" 0 "$owner" "$name"
		done
		if [ "$_includeIPv6" -eq "1" ] ; then 
			ip6=$(getField "$device" 'ip6')
			$send2log "ip6: $ip6" -1
			for ip in $ip6
			do
				[ -z "$(echo "$ip" | grep '(dup)')" ] || continue
				[ -z "$(echo "$ip" | grep -Ei "$_local_ip6")" ] && checkIPTableEntries "ip6tables" "$YAMON_IP6" "$ip" "$mac"
			done
		fi 
		IFS=$'\n'
	done
	unset IFS
	if [ "$_changesInUsersJS" -gt "0" ] ; then
		$send2log ">>> $_changesInUsersJS changes in users.js" 1
		$save2File "$_currentUsers" "$_usersFile"
	fi
}
checkUsers4IP()
{
	$send2log "checkUsers4IP" 0
	local ccd=$(echo "$_currentUsers" | grep 'users_created' | cut -d= -f2)
	ccd=${ccd//\"/}
	[ -z "$ccd" ] && ccd=$(date +"%Y-%m-%d %H:%M:%S")
	IFS=$'\n'
	local ncu="var users_created=\"$ccd\"
	"
	local nline=''
	local cdl=$(echo "$_currentUsers" | grep 'ud_a')
	local dups=''
	for device in $cdl
	do
		local hasIP=$(echo $device | grep '\"ip\"')
		local hasIP6=$(echo $device | grep '\"ip6\"')
		if [ -z "$hasIP" ] && [ -z "$hasIP6" ] ; then
			nline=$(echo $device | sed -e "s~\"owner\"~\"ip\":\"\",\"ip6\":\"\",\"owner\"~Ig" )
		elif [ -z "$hasIP6" ] ; then
			nline=$(echo $device | sed -e "s~\"owner\"~\"ip6\":\"\",\"owner\"~Ig" )
		elif [ -z "$hasIP" ] ; then
			nline=$(echo $device | sed -e "s~\"ip6\"~\"ip\":\"\",\"ip6\"~Ig" )
		else
			nline="$device"
		fi
		local hasLS=$(echo $device | grep '\"last-seen\"')
		if [ -z "$hasLS" ] ; then
			nline=$(echo $device | sed -e "s~})~,\"last-seen\":\"\"})~Ig" )
		fi
		ncu="$ncu
$nline"

		local mac=$(getField "$device" 'mac')
		local nm=$(echo "$cdl" | grep -ic "\b$mac\b")
		[ $nm -eq 1 ] && continue
		local de=$(echo "$dups" | grep -i "$mac")
		if [ -z "$de" ] && [ -z "$dups" ] ; then
			dups="	$mac"
		elif [ -z "$de" ] ; then
			dups="$dups
$mac"
		fi
	done
	[ -n "$dups" ] && [ "$_allowMultipleIPsperMAC" -eq "0" ] && $send2log "There are duplicated mac addresses in $_usersFile:
$dups" 99
	_currentUsers="$ncu"
	$save2File "$_currentUsers" "$_usersFile"
}
createUsersFile()
{
	$send2log "createUsersFile" 0
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	local users=''
	$send2log ">>> Creating empty users file: $_usersFile" -1
	touch $_usersFile
	chmod 666 $_usersFile
	users="var users_created=\"$ds\""
}
setFirmware()
{
	$send2log "setFirmware ($firmware)" 0
	
	if [ -f "/proc/net/ip_conntrack" ] && [ "$_use_nf_conntrack" -ne "1" ] ; then
		_conntrack="/proc/net/ip_conntrack"
		_conntrack_awk='BEGIN { printf "var curr_connections=[ "} { gsub(/(src|dst|sport|dport|bytes)=/, ""); if($1 == "tcp"){ printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$1,$5,$7,$6,$8,$10;} else if($1 == "udp"){ printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$1,$4,$6,$5,$7,$9;} else { printf "[ '\''%s'\'','\''%s'\'','\'\'','\''%s'\'','\'\'','\''%s'\'' ],",$1,$4,$5,$9;} } END { print "[ null ] ]"}'
	
	else
		_conntrack="/proc/net/nf_conntrack"
		_conntrack_awk='BEGIN { printf "var curr_connections=[ "} { gsub(/(src|dst|sport|dport|bytes)=/, ""); if($3 == "tcp"){ printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$3,$7,$9,$8,$10,$12;} else if($3 == "udp"){ printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$3,$6,$8,$7,$9,$11;} else { printf "[ '\''%s'\'','\''%s'\'','\'\'','\''%s'\'','\'\'','\''%s'\'' ],",$3,$6,$7,$9;} } END { print "[ null ] ]"}'
	
	fi
	
	_lan_iface='br0'
	if [ "$_firmware" -eq "1" ] || [ "$_firmware" -eq "4" ] || [ "$_firmware" -eq "6" ] || [ "$_firmware" -eq "7" ] ; then #OpenWRT & variants
		_lan_iface="br-lan"
	fi
	$send2log "_lan_iface: $_lan_iface" 0
	
	_lan_ipaddr=$(ifconfig $_lan_iface | grep 'inet addr:' | tr -s ' ' | cut -d' ' -f3 | cut -d: -f2)
	_lan_hwaddr=$(ifconfig $_lan_iface | grep 'HWaddr' | tr -s ' ' | cut -d' ' -f5 | tr 'A-Z' 'a-z')
	
	_wan_ipaddr=$(ifconfig 'eth0' | grep 'inet addr:' | tr -s ' ' | cut -d' ' -f3 | cut -d: -f2)
	_wan_hwaddr=$(ifconfig 'eth0' | grep 'HWaddr' | tr -s ' ' | cut -d' ' -f5 | tr 'A-Z' 'a-z')
	if [ "$_has_nvram" -eq "1" ] ; then
		[ -z "$_wan_ipaddr" ] && _wan_ipaddr=$(nvram get wan_ipaddr)
		[ -z "$wan_hwaddr" ] && _wan_hwaddr=$(nvram get wan_hwaddr)
		
		[ "$(nvram get lan_proto)" == "dhcp" ] || $send2log "Router is not the DHCP Server for your network... You must enable this feature if you want to use YAMon!" 2
		[ "$_firmware" -eq "0" ] && [ "$(nvram get sfe)" == "1" ] && $send2log "The \`Shortcut Forwarding Engine\` is enabled in your DD-WRT config ($_firmware)... You must disable this feature if you want to use YAMon!" 2
		[ "$(nvram get upnp_enable)" == "1" ] && $send2log "\`UPnP\` is enabled in your DD-WRT config... It is recommended that you disable this feature if you want to use YAMon!" 2
		[ "$(nvram get privoxy_enable)" == "1" ] && $send2log "\`Privoxy\` is enabled in your DD-WRT config... You must disable this feature if you want to use YAMon!" 2
		[ "$(nvram get ntp_enable)" == "1" ] || $send2log "\`NTP Client\` is not enabled in your DD-WRT config... You must enable this feature if you want to use YAMon!" 2
	fi
	_local_ip6=${_local_ip6//,/|}
	[ "$_includeIPv6" -eq "1" ] && _lan_ip6addr=$(ifconfig $_lan_iface | grep 'inet6 addr:' | grep -Ev "$_local_ip6" | tr -s ' ' | cut -d' ' -f4 | cut -d/ -f1)
}
setConfigJS()
{
	$send2log "setConfigJS" 0
	if [ "$_symlink2data" -eq "0" ] ; then
		local configjs="$_wwwPath/$_wwwJS/$_configWWW"
	else
		local configjs="${d_baseDir}/$_webDir/$_wwwJS/$_configWWW"
	fi
	configjs=${configjs//\/\//\/}
	local processors=$(cat /proc/cpuinfo | grep -iE "^processor\s:\s[0-9]{1,}$" -c)

	#Check for directories
	if [ ! -f "$configjs" ] ; then
		$send2log ">>> $_configWWW not found... creating new file: $configjs" 2
		touch $configjs
		chmod 666 $configjs
	fi
	local configtxt="var _ispBillingDay=$_ispBillingDay
var _wwwData='$_wwwData'
var _scriptVersion='$_version'
var _file_version='$_file_version'
var _usersFileName='$_usersFileName'
var _usageFileName='$_usageFileName'
var _hourlyFileName='$_hourlyFileName'
var _alertfilename='$_alertfilename'
var _processors='$processors'
var _doLiveUpdates='$_doLiveUpdates'
var _updatefreq='$_updatefreq'"
	[ "$_includeIPv6" -eq "1" ] && configtxt="$configtxt
var _includeIPv6='1'"
	[ "$_doLiveUpdates" -eq "1" ] && configtxt="$configtxt
var _liveFileName='./$_wwwJS$_liveFileName'
var _doCurrConnections='$_doCurrConnections'"
configtxt="$configtxt
var _monthlyDataCap='$_monthlyDataCap'
var _unlimited_usage='$_unlimited_usage'
var _doLocalFiles='$_doLocalFiles'
var _organizeData='$_organizeData'"
	[ "$_unlimited_usage" -eq "1" ] && configtxt="$configtxt
var _unlimited_start='$_unlimited_start'
var _unlimited_end='$_unlimited_end'"
if [ ! "$_settings_pswd" == "" ] ; then
	local _md5_pswd=$(echo -n "$_settings_pswd" | md5sum | awk '{print $1}')
	configtxt="$configtxt
var _settings_pswd='$_md5_pswd'"
	fi
	[ ! "$_dbkey" == "" ] && configtxt="$configtxt
var _dbkey='$_dbkey'"

	$save2File "$configtxt" "$configjs"

	$send2log ">>> configjs --> $configjs" -1
	$send2log ">>> configtxt --> $configtxt" -1
}
shutDown(){
	#one last backup before shutting down
	$send2log "shutDown" 1

	updateHourly

	$send2log "\`yamon.sh\` has been stopped" 2
	exit 0

}

changeDates()
{
	$send2log ">>> date change: $_pDay --> $_cDay " 1
	
	source "$d_baseDir/includes/hourly2monthly.sh"

	updateHourly $_p_hr
	
	updateHourly2Monthly $_cYear $_cMonth $_pDay &
	
	local avrt='n/a'
	[ "$_dailyiterations" -gt "0" ] && avrt=$(echo "$_totalDailyRunTime $_dailyiterations" | awk '{printf "%.3f \n", $1/$2}')
	$send2log ">>> Daily stats:  day-> $_pDay  #iterations--> $_dailyiterations   total runtime--> $_totalDailyRunTime   Ave--> $avrt	min-> $_daily_rt_min   max--> $_daily_rt_max" 1
	_hriterations=0
	_dailyiterations=0
	_totalhrRunTime=0
	_totalDailyRunTime=0
	_hr_rt_max=''
	_hr_rt_min=''
	_daily_rt_max=''
	_daily_rt_min=''
	
	[ -n "$(which sort)" ] && sortStr=" | sort -k3"
	local yEntry=$(eval "iptables -nL ${YAMON_IP4}Entry -vxZ | tr -s '-' ' ' | cut -d' ' -f2,3,8,9,10 $sortStr")
	local yLocal=$(eval "iptables -nL ${YAMON_IP4}Local -vxZ | tr -s '-' ' ' | cut -d' ' -f2,3,8,9,10 $sortStr")
	local yall=$(eval "iptables -nL ${YAMON_IP4} -vx | tr -s '-' ' ' | cut -d' ' -f2,3,8,9,10 $sortStr")

	$send2log ">>> YAMON33v4Entry:
$yEntry" 0
	$send2log ">>> YAMON33v4Local:
$yLocal" 0
	$send2log ">>> yall:
$yall" 0
	[ "$_doDailyBU" -eq "1" ] && dailyBU "$_cYear-$_cMonth-$_pDay" &
	sl_max=''
	sl_min=''
	hr_max5=''
	hr_min5=''
	hr_max1=''
	hr_min1=''
	sl_max_ts=''
	sl_min_ts=''
	ndAMS=0
	_totalLostBytes=0
	_pndData=""

	_cMonth=$(date +%m)
	_cYear=$(date +%Y)
	_ds="$_cYear-$_cMonth-$_cDay"
	if [ "$_unlimited_usage" -eq "1" ] ; then
		_ul_start=$(date -d "$_unlimited_start" +%s);
		_ul_end=$(date -d "$_unlimited_end" +%s);
		[ "$_ul_end" -lt "$_ul_start" ] && _ul_start=$((_ul_start - 86400))
		$send2log "_unlimited_usage-->$_unlimited_usage ($_unlimited_start->$_unlimited_end / $_ul_start->$_ul_end)" 0
	fi

	setLogFile
	updateServerStats
	setDataDirectories
	_pDay="$_cDay"
}
add2UsersJS()
{
	$send2log "add2UsersJS:  $1	$2	$3	$4	$5" 0
	local mac=$1
	local ip=$2
	local is_ipv6=$3
	local oname=''
	local dname=''
	[ -n "$4" ] && oname="$4"
	[ -n "$5" ] && dname="$5"
	$send2log "add2UsersJS:  $mac	$ip	$is_ipv6 / $oname / $dname" 1

	[ -z "$ip" ] || clearDupIPs

	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	if [ -z "$dname" ] ; then
		local deviceName=$(getDeviceName $mac)
		$send2log "deviceName-->$deviceName" -1
		if [ -z "$_do_separator" ] ; then
			dname="$deviceName"
		else
			[ -z "$oname" ] && oname=${deviceName%%"$_do_separator"*}
			dname=${deviceName#*"$_do_separator"}
		fi
	fi
	
	#add count of new devices
	local inc_count=$(echo "$_currentUsers" | grep -c "$_defaultDeviceName")
	inc_count=$(printf %02d $(($inc_count+1)) )

	[ -z "$dname" ] || [ "$dname" == '*' ] && dname="$_defaultDeviceName-$inc_count"
	[ -z "$oname" ] || [ "$oname" == '*' ] && oname="$_defaultOwner"

	if [ "$is_ipv6" -eq '0' ] ; then
		local ip_str="\"ip\":\"$ip\","
		local ip6_str=""
		[ "$_includeIPv6" -eq "1" ] && ip6_str="\"ip6\":\"\","
	else
		local ip_str="\"ip\":\"\","
		local ip6_str="\"ip6\":\"$ip\","
	fi
	unset IFS
	local newuser="ud_a({\"mac\":\"$mac\",$ip_str$ip6_str\"owner\":\"$oname\",\"name\":\"$dname\",\"colour\":\"\",\"added\":\"$ds\",\"updated\":\"$ds\",\"last-seen\":\"$ds\"})"
	$send2log "New device $dname (group $oname) was added to the network: $mac & $ip ($is_ipv6)" 99
	$send2log "newuser-->$newuser" -1
	_changesInUsersJS=$(($_changesInUsersJS + 1))
	_currentUsers="$_currentUsers
$newuser"
	$send2log "_currentUsers-->$_currentUsers" -1
}
updateinUsersJS()
{
	$send2log "updateinUsersJS" 0
	
	[ -z "$tip" ] && tip=${ip//\./\\.}
	[ -z "$ip" ] || clearDupIPs
	[ -z "$ip" ] || mline=$(echo "$mline" | sed -re "s~([\b,\"])$tip([,\b\"])~\1$ip (dup)\2~Ig")
	unset IFS
	$send2log "mline: $mline
mac: $mac
ip: $ip
tip: $tip
wip: $wip
o_ip: $o_ip" -1

	newline=$(replace "$mline" "$wip" "$ip")
	newline=$(replace "$newline" "updated" "_updated_")
	
	$send2log "newline: $newline" -1
	_currentUsers=$(echo "$_currentUsers" | sed -e "s~$mline~$newline~Ig")
	_changesInUsersJS=$(($_changesInUsersJS + 1))
	
	$send2log ">>> Device $mac & $o_ip was updated to $mac & $ip" 1
}
clearDupIPs()
{
	$send2log "clearDupIPs: ip: $ip" 1 
	[ -z "$ip" ] && return
	local tip=${ip//\./\\.}
	_currentUsers=$(echo "$_currentUsers" | sed -re "s~([\b,\"])$tip([,\b\"])~\1$ip (dup)\2~Ig" | sed -e "s~$tip (dup) (dup)~$ip (dup)~Ig")
}

checkIPs()
{
	checkBridgeMac()
	{
		$send2log "checkBridgeMac" 0
		_bridgeMAC=${_bridgeMAC//,/|}
		local bridged=$(echo "$iplist" | grep -Ei "$_bridgeMAC")
		[ -z "$bridged" ] && return
		local cu_bridged=$(echo "$_currentUsers" | grep -Ei "$_bridgeMAC")
		local l_bridgeMAC="$_bridgeMAC"
		[ -z "$l_bridgeMAC" ] && l_bridgeMAC='XX:XX:XX:XX:XX:XX'

		local cu_not_bridged=$(echo "$_currentUsers" | grep -Eiv "$l_bridgeMAC")
		
		local num_bridged=$(echo "$(getField "$cu_bridged" "mac")" | cut -d'-' -f2)
		[ -z "$num_bridged" ] || [ "$num_bridged" == "$_bridgeMAC" ] && num_bridged=0

		$send2log "bridged: $bridged" -1
		IFS=$'\n'
		for line in $bridged
		do
			[ -z "$line" ] && continue
			local ip=$(echo "$line" | cut -d' ' -f1)
			local tip=${ip//\./\\.}
			local mac=$(echo "$line" | cut -d' ' -f2)
			
			local o_mac=$mac
			local uline=$(echo "$cu_not_bridged" | grep -i "[\b\",]$tip[,\"]")
			#uline gets just matching `active` IPs... not (dup) IPs
			if [ -z "$uline" ] ; then  #no match
				local mline=$(echo "$cu_bridged" | grep -Ei "\b$tip\b")
				#dline gets just bridged entries with matching IPs
				if [ -z "$mline" ] ; then	#no matching inactive IPs... add a new entr
					num_bridged=$(($num_bridged+1))
					mac="br:id:ge:dm:ac-$num_bridged"
					$send2log "Changed bridged MAC for IP: $ip from $o_mac to $mac" 0
					add2UsersJS "$mac" "$ip" "$is_ipv6" 'Unknown' "Bridged-$num_bridged"
				else
					local nm=$(echo "$mline" | wc -l)
					if [ "$nm" -eq '1' ] ; then
						mac=$(getField "$mline" 'mac')
						o_ip=$(getField "$mline" "$wip")
						$send2log "Changed bridged MAC for IP: $ip from $o_mac to $mac" 0
						[ -z "$(echo $o_ip | grep '(dup)')" ] || updateinUsersJS
					else
						$send2log "$nm bridged MACs with duplicate IP: $ip - not sure what to do
$mline" 2
					fi
				fi
			else
				local nm=$(echo "$uline" | wc -l) 
				if [ "$nm" -eq "1" ] ; then	# match... nothing to do really
					$send2log "Changed bridged MAC for IP: $ip from $o_mac to $mac" 0
					mline="$uline"
					o_ip=$(getField "$mline" "$wip")
					[ -z "$(echo $o_ip | grep '(dup)')" ] || updateinUsersJS
				else   # too many matches... mark both as duplicate
					$send2log "$nm active IPs in users.js for $ip - marking all as duplicate
$uline" 2
					[ -z "$ip" ] || clearDupIPs
				fi
			fi
		done
		unset IFS
	}


	checkIncompleteMac()
	{
		local incomplete=$(echo "$iplist" | grep -Ei "00:00:00:00:00:00|failed|incomplete")
		[ -z "$incomplete" ] && return
		local cu_inc=$(echo "$_currentUsers" | grep -i "in:co:mp:le:te" | sort -r)
		local cu_not_inc=$(echo "$_currentUsers" | grep -iv "in:co:mp:le:te")

		$send2log "checkIncompleteMac: $incomplete" 0
		IFS=$'\n'
		for line in $incomplete
		do
			[ -z "$line" ] && continue
			local ip=$(echo "$line" | cut -d' ' -f1)
			local tip=${ip//\./\\.}
			local mac=$(echo "$line" | cut -d' ' -f2)

			local o_mac=$mac
			$send2log "Incomplete MAC ($mac) for IP: $ip" 0
			local uline=$(echo "$cu_not_inc" | grep -i "[\b\",]$tip[,\"]")
			#uline gets just matching `active` IPs... not (dup) IPs
			if [ -z "$uline" ] ; then  #no match
				local mline=$(echo "$cu_inc" | grep -Ei "\b$tip\b")
				#mline gets just in:co:mp:le:te entries with matching IPs
				$send2log "mline: $mline" 0
				if [ -z "$mline" ] ; then	#no matching inactive IPs... add a new entry
					local num_inc=$(echo "$(getField "$cu_inc" "mac")" | cut -d'-' -f2)
					[ -z "$num_inc" ] && num_inc=0
					num_inc=$(printf %02d $((${num_inc#0}+1)))
					mac="in:co:mp:le:te-$num_inc"
					$send2log "Changed incomplete MAC for IP: $ip from $o_mac to $mac" 0
					add2UsersJS "$mac" "$ip" "$is_ipv6" 'Unknown' "Incomplete-$num_inc"
				else
					local nm=$(echo "$mline" | wc -l)
					if [ "$nm" -eq '1' ] ; then
						mac=$(getField "$mline" 'mac')
						o_ip=$(getField "$mline" "$wip")
						$send2log "Changed incomplete MAC for IP: $ip from $o_mac to $mac" 0
						[ -z "$(echo $o_ip | grep '(dup)')" ] || updateinUsersJS
					else
						$send2log "$nm incomplete MACs with duplicate IP: $ip - not sure what to do
$mline" 2
					fi
				fi
			else
				$send2log "uline: $uline" 0
				local nm=$(echo "$uline" | wc -l) 
				if [ "$nm" -eq "1" ] ; then	# match... nothing to do really
					mline="$uline"
					mac=$(getField "$mline" 'mac')
					o_ip=$(getField "$mline" "$wip")
					$send2log "Changed incomplete MAC for IP: $ip from $o_mac to $mac" 0
					[ -z "$(echo $o_ip | grep '(dup)')" ] || updateinUsersJS
				else   # too many matches... mark both as duplicate
					$send2log "$nm active IPs in users.js for $ip - marking all as duplicate
$uline" 2
					[ -z "$ip" ] || clearDupIPs
				fi
			fi
		done
		unset IFS
	}
	multipleIPsperMAC()
	{
		$send2log "multipleIPsperMAC" 0
		
		local multi=$(echo "$iplist" | grep -i "$_multipleIPMAC")
		[ -z "$multi" ] && return
		local cu_multi=$(echo "$_currentUsers" | grep -i "$_multipleIPMAC" | sort -r)
		$send2log "cu_multi: $cu_multi" -1
		local num_multi=$(echo "$(getField "$cu_multi" "mac")" | cut -d'-' -f2)
		[ -z "$num_multi" ] || [ "$num_multi" == "$_multipleIPMAC" ] && num_multi=0
		$send2log "multi: $multi" -1
		IFS=$'\n'
		for line in $multi
		do
			[ -z "$line" ] && continue
			local ip=$(echo "$line" | cut -d' ' -f1)
			local tip=${ip//\./\\.}
			local mac=$(echo "$line" | cut -d' ' -f2)
			
			local mline=$(echo "$cu_multi" | grep -i "\b$tip\b")
			if [ -z "$mline" ] ; then
				num_multi=$(($num_multi+1))
				mac="$mac-$num_multi"
				$send2log "Adding multi IP entry: $mac / $ip" 1
				add2UsersJS "$mac" "$ip" "$is_ipv6" 'Unknown' "Multi-IP-$num_multi"
			else
				local nm=$(echo "$mline" | wc -l)
				if [ "$nm" -eq '1' ] ; then
					local o_ip=$(getField "$mline" "$wip")
					$send2log "o_ip: $o_ip / wip: $wip " 0
					[ -z "$(echo $o_ip | grep '(dup)')" ] || updateinUsersJS
				else
					$send2log "huh?!? there are $nm matches for $ip in users.js
$mline" 2				
				fi
			fi
		done 
		unset IFS
	}
	checkRegularMac()
	{
		getReg_0()
		{ #for firmware without sort/uniq
			local retlist=''
			IFS=$'\n'
			for lline in $regular_list
			do
				local lmac=$(echo $lline | cut -d' ' -f2)
				local count=$(echo "$retlist" | grep $lmac | cut -d' ' -f2)
				if [ -z "$count" ] ;  then
					retlist=" 1 $lline
$retlist"
				else
					count=$((count+1))
					retlist=$( echo "$retlist" | sed -e "s~.*$lline~ $count $lline~")
				fi
			done
			echo "$retlist"
		}
		
		getReg_1()
		{ #for firmware with sort/uniq
			echo "$regular_list" | sort -k2 | uniq -c -f1 | tr -s ' '
		}
		
		$send2log "checkRegularMac" 0
				
		local l_bridgeMAC="$_bridgeMAC"
		[ -z "$l_bridgeMAC" ] && l_bridgeMAC='XX:XX:XX:XX:XX:XX'
		local l_multipleIPMAC="$_multipleIPMAC"
		[ -z "$l_multipleIPMAC" ] && l_multipleIPMAC='XX:XX:XX:XX:XX:XX'
		local regular_list=$(echo "$iplist" | grep -Eiv "00:00:00:00:00:00|failed|incomplete|$l_bridgeMAC|$l_multipleIPMAC")
		[ -z "$regular_list" ] && return
		local regular=$(eval "getReg_$hasUniq")
		
		local cu_regular=$(echo "$_currentUsers" | grep -Eiv "in:co:mp:le:te|$l_bridgeMAC|$l_multipleIPMAC")
		$send2log "regular: $regular" -1
		$send2log "cu_regular: $cu_regular" -1
		IFS=$'\n'
		for line in $regular
		do
			[ -z "$line" ] && continue
			$send2log "line: $line" -1
			local count=$(echo "$line" | cut -d' ' -f2)
			local mac=$(echo "$line" | cut -d' ' -f4 )
			if [ $count -eq "1" ] ; then
				local ip=$(echo "$line" | cut -d' ' -f3)
			else
				local ip=$(echo "$regular_list" | grep $mac | cut -d' ' -f1 | tr -s "\n" ",")
				ip=${ip%,}
			fi
			
			local tip=${ip//\./\\.}
			$send2log "count: $count / ip: $ip / mac: $mac" -1
			
			local mline=$(echo "$cu_regular" | grep -i "$mac")
			if [ -z "$mline" ] ; then
				add2UsersJS $mac $ip $is_ipv6
			else
				local nm=$(echo "$mline" | wc -l)
				if [ "$nm" -eq '1' ] ; then
					local o_ip=$(getField "$mline" "$wip")
					$send2log "o_ip: $o_ip / wip: $wip " -1
					$send2log "mline: $mline " -1
					[ "$o_ip" == "$ip" ] || updateinUsersJS
				elif [ "$nm" -eq '0' ]  ; then
					$send2log "huh?!? checkRegularMac: this should be impossible $mline / $mac" 2
				else
					$send2log "Uh oh?!? there are $nm matches for $mac in users.js
$mline" 2
				fi
			fi
		done
		unset IFS
	}
	checkIPList()
	{
		$send2log "checkIPList:	$1 / $2 / $3" 0
		local cmd="$1"
		local rule="$2"
		local is_ipv6="$3"
		
		local wip='ip'
		[ "$is_ipv6" -eq "1" ] && wip='ip6'

		IFS=$'\n'
		for line in $iplist
		do
			[ -z "$line" ] && continue
			local ip=$(echo "$line" | cut -d' ' -f1)
			local tip=${ip//\./\\.}
			local mac=$(echo "$line" | cut -d' ' -f2)
			$send2log "mac-->$mac  ip-->$ip" -1
			checkIPTableEntries "$cmd" "$rule" "$ip" "$mac"
		done
		unset IFS
		
		checkRegularMac
		[ "$_includeIncomplete" -eq "1" ] && checkIncompleteMac
		[ "$_includeBridge" -eq "1" ] && checkBridgeMac
		[ "$_allowMultipleIPsperMAC" -eq "1" ] && multipleIPsperMAC

	}
	checkIPv6_0()
	{
		$send2log "checkIPv6_0" -1
		return
	}
	checkIPv6_1()
	{
		$send2log "checkIPv6_1" -1
		local iplist=$(eval "$_getIP6List")
		if [ "$iplist" == "$_p_ip6list" ] ; then
			$send2log ">>> ip 6 list did not change" 0
		else
			$send2log ">>> ip 6 list changed->
$iplist" 0
			_p_ip6list="$iplist"
			checkIPList "ip6tables" "$YAMON_IP6" 1
		fi
	}
	$send2log "checkIPs" 0
	_changesInUsersJS=0
	
	local iplist=$(eval "$_getIP4List")
	if [ "$iplist" == "$_p_ip4list" ] ; then
		$send2log ">>> ip 4 list did not change" 0
	else
		$send2log ">>> ip 4 list changed ->
$iplist" 0
		_p_ip4list="$iplist"
		checkIPList "iptables" "$YAMON_IP4" 0
	fi

	$checkIPv6

	if [ "$_changesInUsersJS" -gt "0" ] ; then
		$send2log ">>> $_changesInUsersJS changes in users.js" 1
		
		local ds=$(date +"%Y-%m-%d %H:%M:%S")
		_currentUsers=$(echo "$_currentUsers" | sed -e "s~_updated_~$ds~Ig")

		$save2File "$_currentUsers" "$_usersFile"
	fi
}
CheckUsersJS()
{

	updateDetailsinUsersJS()
	{
		$send2log "updateDetailsinUsersJS $oname / $dname" 0
		
		newline=$(replace "$mline" "owner" "$oname")
		newline=$(replace "$newline" "name" "$dname")
		newline=$(replace "$newline" "updated" "_updated_")
		
		_currentUsers=$(echo "$_currentUsers" | sed -e "s~$mline~$newline~Ig")
		_changesInUsersJS=$(($_changesInUsersJS + 1))

		$send2log ">>> Device details for $mac & $ip were updated to $oname & $dname
$newline" 1

	}
	$send2log "CheckUsersJS: $1 / $2 / $3 / $4 / $5 / $6" 0

	local mac=$1
	local ip=$2
	local is_ipv6=$3
	local oname=''
	local dname=''
	local append=''
	[ -n "$4" ] && oname="$4"
	[ -n "$5" ] && dname="$5"
	[ -n "$6" ] && append="$6"	

	local wip='ip'
	[ "$is_ipv6" -eq "1" ] && wip='ip6'

	local tip=${ip//\./\\.}
	local mline=$(echo "$_currentUsers" | grep -Ei "\b$mac\b")

	if [ -z "$mline" ] ; then
		add2UsersJS "$mac" "$ip" "$is_ipv6" "$oname" "$dname" 
	else
		local nm=$(echo "$mline" | wc -l)
		if [ "$nm" -eq "1" ] && [ -n "$append" ] ; then
			local o_ip=$(getField "$mline" "$wip")
			[ "$o_ip" == "$ip" ] && return
			$send2log "	>>> $mac exists in $_usersFileName... updating $wip to '$ip' / o_ip: $o_ip" 2
			[ -z "$o_ip" ] && updateinUsersJS
			[ -z "$(echo $o_ip | grep '(dup)')" ] && updateinUsersJS
		elif [ "$nm" -eq '1' ] ; then
			local o_ip=$(getField "$mline" "$wip")
			local o_o=$(getField "$mline" "owner")
			local o_n=$(getField "$mline" "name")
			if [ ! "$o_ip" == "$ip" ] ; then
				$send2log "IP for $mac ($ip) changed: ip-->$o_ip / $ip" 0
				updateinUsersJS
				mline=$(replace "$mline" "$wip" "$ip")
				mline=$(replace "$mline" "updated" "_updated_")

			fi
			[ -z "$oname" ] && [ -z "$dname" ] && return
			if [ ! "$o_o" == "$oname" ] || [ ! "$o_n" == "$dname" ] ; then
				[ "$oname" == "$_defaultOwner" ] && oname=$o_o
				$send2log "Details for $mac ($ip) changed: owner-->$o_o / $oname     name-->$o_n / $dname" 1
				updateDetailsinUsersJS
			fi
	
		elif [ "$nm" -eq '0' ]  ; then
			$send2log "huh?!? CheckUsersJS: this should be impossible $mline / $mac" 2
		else
			$send2log "Uh oh?!? There are $nm matches for $mac in users.js
$mline" 2
		fi
	fi
	
}
getDeviceName()
{
	$send2log "getDeviceName:  $1" 0
	local mac=$1
	local namefield=2
	
	if [ "$_firmware" -eq "0" ] ; then
		local nvr=$(nvram show 2>&1 | grep -i "static_leases=")
		local result=$(echo "$nvr" | grep -io "$mac[^=]*=.\{1,\}=.\{1,\}=" | cut -d= -f2)
	elif [ "$_firmware" -eq "1" ] || [ "$_firmware" -eq "4" ] || [ "$_firmware" -eq "6" ] || [ "$_firmware" -eq "7" ] ; then
		# thanks to Robert Micsutka for providing this code & easywinclan for suggesting & testing improvements!
		local ucihostid=$(uci show dhcp | grep -i $mac | cut -d. -f2)
		[ -n "$ucihostid" ] && local result=$(uci get dhcp.$ucihostid.name)
		namefield=3
	elif [ "$_firmware" -eq "2" ] || [ "$_firmware" -eq "5" ] ; then
		#thanks to Chris Dougherty for providing this code
		local nvr=$(nvram show 2>&1 | grep -i "dhcp_staticlist=")
		local nvrt=$nvr
		local nvrfix=''
		while [ "$nvrt" ] ;do
			iter=${nvrt%%<*}
			nvrfix="$nvrfix$iter="
			[ "$nvrt" = "$iter" ] && \
				nvrt='' || \
				nvrt="${nvrt#*<}"
		done
		local nvr=${nvrfix//>/=}
			#local result=$(echo "$nvr" | grep -io "$mac=.\{1,\}=.\{1,\}=" | cut -d= -f3)
		local result=$(echo "$nvr" | grep -io "$mac[^=]*=.\{1,\}=.\{1,\}=" | cut -d= -f3)
	fi
	
	[ -z "$result" ] && [ -f "$_dnsmasq_conf" ] && result=$(echo "$(cat $_dnsmasq_conf | grep -i "dhcp-host=")" | grep -i "$mac" | cut -d, -f$namefield)
	[ -z "$result" ] && [ -f "$_dnsmasq_leases" ] && result=$(echo "$(cat $_dnsmasq_leases)" | grep -i "$mac" | tr '\n' ' / ' | cut -d' ' -f4)
	echo "$result"
}
updateStaticLeases(){
	$send2log "updateStaticLeases" -1
	[ ! -f "$_dnsmasq_conf" ] && return
	_changesInUsersJS=0
	local leases=$(cat $_dnsmasq_conf | grep dhcp-host)
	local namefield=2
	local ipfield=3

	if [ "$_firmware" -eq "1" ] || [ "$_firmware" -eq "4" ] || [ "$_firmware" -eq "6" ] || [ "$_firmware" -eq "7" ] ; then
		namefield=3
		ipfield=2
	fi
	#ToDo - add code that parses the contents of /etc/config/dhcp 
	$send2log "updateStaticLeases --> leases ($namefield / $ipfield) :
$leases" 0
	IFS=$'\n'
	for line in $leases
	do
		local str=${line//dhcp-host=/}
		local mac=$(echo $str | cut -d, -f1)
		local ip=$(echo $str | cut -d, -f$ipfield)
		local name=$(echo $str | cut -d, -f$namefield)
		local owner="$_defaultOwner"
		if [ ! -z "$_do_separator" ] ; then
			owner=$(echo $name | cut -d$_do_separator -f1)
			name=$(echo $name | cut -d$_do_separator -f2)
		fi
		[ "$name" == "$owner" ] && owner="$_defaultOwner"
		$send2log "mac-->$mac    ip-->$ip     owner-->$owner     name-->$name" -1
		CheckUsersJS $mac "$ip" 0 "$owner" "$name"
	done
	if [ "$_changesInUsersJS" -gt "0" ] ; then
		local ds=$(date +"%Y-%m-%d %H:%M:%S")
		_currentUsers=$(echo "$_currentUsers" | sed -e "s~_updated_~$ds~Ig")

		$send2log ">>> $_changesInUsersJS changes in users.js" 99
		$save2File "$_currentUsers" "$_usersFile"
	fi
}
checkUnlimited_0()
{	#_unlimited_usage=0
	$send2log "checkUnlimited_0" -1
	return
}
checkUnlimited_1()
{	#_unlimited_usage=1
	$send2log "checkUnlimited_1" -1
	local currTime=$(date +"%s")
	_inUnlimited=$((currTime >= _ul_start && currTime <= _ul_end))
	[ "$_inUnlimited" -eq "1" ] && [ "$_p_inUnlimited" -eq "0" ] && $send2log "starting unlimited usage interval: $_unlimited_start" 1
	[ "$_inUnlimited" -eq "0" ] && [ "$_p_inUnlimited" -eq "1" ] && $send2log "ending unlimited usage interval: $_unlimited_end" 1
	_p_inUnlimited=$_inUnlimited
	return
}
checkTimes()
{	#_unlimited_usage=0
	$send2log "checkTimes" -1
	_cDay=$(date +"%d")
	[ "$_cDay" != "$_pDay" ] && changeDates

	local hr=$(date +"%H")
	[ "$hr" -ne "$_p_hr" ] && changeHour "$hr"
	
	$checkUnlimited
}
changeHour()
{
	local hr="$1"
	updateHourly $_p_hr
	$send2log ">>> hour change: $_p_hr --> $hr " 0
	local avrt='n/a'
	[ "$_hriterations" -gt "0" ] && avrt=$(echo "$_totalhrRunTime $_hriterations" | awk '{printf "%.3f \n", $1/$2}')
	$send2log ">>> Hourly stats:  hr-> $_p_hr  #iterations--> $_hriterations   total runtime--> $_totalhrRunTime   Ave--> $avrt	min-> $_hr_rt_min   max--> $_hr_rt_max" 1
	_dailyiterations=$(($_dailyiterations+$_hriterations))
	_totalDailyRunTime=$(($_totalDailyRunTime+$_totalhrRunTime))
	_daily_rt_max=$(maxI $_daily_rt_max $_hr_rt_max )
	_daily_rt_min=$(minI $_daily_rt_min $_hr_rt_min )
	$send2log "_thisHrpnd ($_p_hr): $_thisHrpnd" 1

	_hr_rt_max=''
	_hr_rt_min=''
	_hriterations=0
	_totalhrRunTime=0
	hr_max5=''
	hr_min5=''
	hr_max1=''
	hr_min1=''
	_totalLostBytes=0

	if [ -n "$end" ] ; then
		$send2log "_thisHrdata: ($_p_hr)
$_thisHrdata" 1
		_hourlyData="$_hourlyData
$_thisHrdata"
		$send2log "_thisHrpnd: ($_p_hr)
$_thisHrpnd" 1
		_pndData="$_pndData
$_thisHrpnd"
	fi
	_thisHrdata=''
	_thisHrpnd=''
	_p_hr=$hr
	
	local disk_utilization=$(df "${d_baseDir}" | tail -n 1 | tr -s ' ' | cut -d' ' -f5)

	if 	[ "$disk_utilization" \> "90%" ] ; then
		$send2log "Disk usage is becoming critically high ($disk_utilization)" 99
	elif [ "$disk_utilization" \> "75%" ] ; then
		$send2log "Disk usage is more than $disk_utilization" 2
	elif [ "$disk_utilization" \> "50%" ] ; then
		$send2log "Disk usage is more than $disk_utilization" 1
	fi
	$send2log "getHourlyHeader:_totMem-->$_totMem" -1

}
updateServerStats()
{
	$send2log "updateServerStats " -1
	local cTime=$(date +"%T")
	if [ -z "$sl_max" ] || [ "$sl_max" \< "$load5" ] ; then
		sl_max=$load5
		sl_max_ts="$cTime"
	fi
	if [ -z "$sl_min" ] || [ "$load5" \< "$sl_min" ] ; then
		sl_min="$load5"
		sl_min_ts="$cTime"
	fi
	hr_max1=$(maxF $hr_max1 $load1 )
	hr_max5=$(maxF $hr_max5 $load5 )
	hr_min1=$(minF $hr_min1 $load1 )
	hr_min5=$(minF $hr_min5 $load5 )
}

doliveUpdates_0()
{ #doliveUpdates=0
	$send2log "doliveUpdates" -1
	return
}
doliveUpdates_1()
{ #doliveUpdates=1
	$send2log "doliveUpdates_1" -1
	$send2log "_liveFilePath: $_liveFilePath" -1
	local loadavg=$(cat /proc/loadavg)
	$send2log ">>> loadavg: $loadavg" -1
	load1=$(echo "$loadavg" | cut -f1 -d" ")
	load5=$(echo "$loadavg" | cut -f2 -d" ")
	local load15=$(echo "$loadavg" | cut -f3 -d" ")
	local cTime=$(date +"%T")
	echo "var last_update='$_cYear/$_cMonth/$_cDay $cTime'
serverload($load1,$load5,$load15)" > $_liveFilePath

	if [ "$_doCurrConnections" -eq "1" ] ; then
		$send2log ">>> curr_connections" -1
		local ddd=$(awk "$_conntrack_awk" "$_conntrack")
		err=$(echo "$ddd" 2>&1 1>> $_liveFilePath)
        $send2log "curr_connections >>>\n$ddd" -1
        [ -n "$err" ] && $send2log "ERR >>> doliveUpdates (ddd): $err" 0
		#echo "$ddd"  >> $_liveFilePath
	fi

	$send2log ">>> _liveusage: $_liveusage" -1
	echo "$_liveusage" >> $_liveFilePath
	_liveusage=''
 	[ "$_doArchiveLiveUpdates" -eq "1" ] && cat "$_liveFilePath" >> $_liveArchiveFilePath
}
checkConfig()
{
	local dcf=$(date -r "$d_baseDir/default_config.file" +%s)
	local cf=$(date -r "$_configFile" +%s)
	$send2log "checkConfig:  dcf: $dcf	cf: $cf" 0	
	[ "$cf" \< "$dcf" ] && return
	touch "$d_baseDir/default_config.file"
	$send2log "checkConfig >>> config.file has changed!  Resetting setInitValues ---" 2
	setConfigJS
	[ "$_enable_ftp" -eq 1 ] && send2FTP "$_configFile"
	updateHourly
	setInitValues
}
checkChainEntries()
{
	$send2log "checkChainEntries: $1 / $2" 0

	local nr=$(eval $1 $_tMangleOption -nL "$2" | wc -l)
	if [ "$nr" -lt '3' ] ; then
		#$send2log "checkChainEntries: $2 returned only $nr entries?!? Resetting $cmd rules" 2
		#setUsers
		local fc=$(iptables -nL FORWARD)
		local yc=$(iptables -L | grep "Chain YAMON")
		$send2log "checkChainEntries: Restarting because iptables is in a bad state -->$2 returned only $nr entries?!? 
FORWARD Chain:
$fc

---------------
YAMon Chains:
$yc" 99
		$d_baseDir/restart.sh 0 &
	fi
}
checkChains_1()
{
	$send2log "checkChains_1 " 0
	checkChainEntries "iptables" "$YAMON_IP4"
	checkChainEntries "ip6tables" "$YAMON_IP6"
}
checkChains_0()
{
	$send2log "checkChains_0 " 0
	checkChainEntries "iptables" "$YAMON_IP4"
}
update()
{
	$send2log "update " 0
	newHourlyLine_0()
	{	#_inUnlimited=0
		$send2log "newHourlyLine_0 " -1
		echo "hu({\"mac\":\"$mac\",\"hour\":\"$hr\","\"down\":$new_do,\"up\":$new_up"})"
	}
	newHourlyLine_1()
	{	#_inUnlimited=1
		$send2log "newHourlyLine_1 " -1
		echo "hu({\"mac\":\"$mac\",\"hour\":\"$hr\","\"down\":$new_do,\"up\":$new_up","\"ul_do\":$new_do,\"ul_up\":$new_up"})"
	}
	updateHourlyLine_0()
	{	#_inUnlimited=0
		$send2log "updateHourlyLine_0 " -1
		echo "hu({\"mac\":\"$mac\",\"hour\":\"$hr\","\"down\":$new_do,\"up\":$new_up"})"
	}
	updateHourlyLine_1()
	{	#_inUnlimited=1
		$send2log "updateHourlyLine_1 " -1
		local pul_do=$(getCV "$cur_hd" "ul_do")
		local pul_up=$(getCV "$cur_hd" "ul_up")
		local new_ul_do=$(digitAdd "$do" "$pul_do")
		local new_ul_up=$(digitAdd "$up" "$pul_up")
		echo "hu({\"mac\":\"$mac\",\"hour\":\"$hr\","\"down\":$new_do,\"up\":$new_up","\"ul_do\":$new_ul_do,\"ul_up\":$new_ul_up"})"
	}
	lostBytes()
	{
		$send2log "lostBytes:  $1	$2" 0
		local nb=$2
		[ -z "$nb" ] && nb=0
		_totalLostBytes=$(digitAdd "$_totalLostBytes" "$nb")
		$send2log "$1 (_totalLostBytes=$_totalLostBytes / $nb)" 2
	}
	

	$send2log "update arguments: $1 $2 $3 $4" -1

	local ds=$(date +"%Y-%m-%d %H:%M:%S")

	local ip="${1%/128}"
	local tip=${ip//\./\\.}
	local do="$2"
	local up="$3"
	local hr="$4"
	local bytes=$(digitAdd "$do" "$up")
	local cu_no_dup=$(echo "$_currentUsers" | grep -vi "$tip (dup)")
	local cuc=$(echo "$cu_no_dup" | grep -ic "[\b\",]$tip\b")
	if [ "$cuc" -eq 0 ] ; then
		lostBytes "!!! No matching entry in _currentUsers for $mac / $ip ($tip)?!? - adding $bytes to unknown mac 
$_ud_list" $bytes
		update "$_generic_ipv4" "$do" "$up" "$hr"
		return
	elif [ "$cuc" -gt 1 ] ; then
		$send2log "cu_no_dup: $cu_no_dup" -1
		lostBytes "!!! $cuc matching entries in _currentUsers for $ip ($tip / $mac)?!? returning - adding $bytes to unknown mac " $bytes
		update "$_generic_ipv4" "$do" "$up" "$hr"
		return
	fi
	local pdo=0
	local pup=0

	local new_do=$do
	local new_up=$up
	[ -z "$new_do" ] && new_do=0
	[ -z "$new_up" ] && new_up=0
	local cu=$(echo "$cu_no_dup" | grep -i "[\b\",]$tip\b")
	local mac=$(getField "$cu" 'mac')
	if [ -z "$mac" ] ; then
		$send2log "cu-->$cu" -1
		lostBytes "!!! No matching MAC in _currentUsers for $ip?!? - adding $bytes to unknown mac " $bytes
		update "$_generic_ipv4" "$new_do" "$new_up" "$hr"
		return
	elif [ "$mac" == "00:00:00:00:00:00" ] || [ "$mac" == "failed" ] || [ "$mac" == "incomplete" ] ; then
		lostBytes ">>> skipping null/invalid MAC address for $ip?!? - adding $bytes to unknown mac " $bytes
		update "$_generic_ipv4" "$new_do" "$new_up" "$hr"
		return
	elif [ "$_includeBridge" -eq "1" ] && [ "$mac" == "$_bridgeMAC" ] ; then
		if [ "$ip" == "$_bridgeIP" ] ; then
			continue
		else
			local ipcount=$(echo "$cu_no_dup" | grep -v "\b$_bridgeMAC\b" | grep -ic "[\b\",]$tip\b")
			if [ "$ipcount" -eq 1 ] ;  then
				mac=$(echo "$cu_no_dup" | grep -i "[\b\",]$tip\b" | grep -io '\([a-z0-9]\{2\}\:\)\{5,\}[a-z0-9]\{2\}')
				$send2log "matched bridge mac and found a unique entry for associated IP: $ip.  Changing MAC from $_bridgeMAC (bridge) to $mac (device)" 1
			else
				$send2log "matched bridge mac but found $ipcount matching entries for $ip.  Data will be tallied under bridge mac" 1
			fi
		fi
	fi
	_liveusage="$_liveusage
curr_users({mac:'$mac',ip:'$ip',down:$new_do,up:$new_up})"
	[ "$_ignoreGateway" -eq "1" ] && [ "$mac" == "$_gatewayMAC" ] && return
	local cur_hd=$(echo "$_thisHrdata" | grep -i "\"$mac\".\{0,\}\"$hr\"")
	if [ -z "$cur_hd" ] ; then
		cur_hd=$(eval "newHourlyLine_"$_inUnlimited)
		
		$send2log "new ul row-->$cur_hd" 1
		_thisHrdata="$_thisHrdata
$cur_hd"
		return
	fi
	pdo=$(getCV "$cur_hd" "down")
	pup=$(getCV "$cur_hd" "up")
	new_do=$(digitAdd "$do" "$pdo")
	new_up=$(digitAdd "$up" "$pup")
	
	cur_hd=$(eval "updateHourlyLine_"$_inUnlimited)
	
	$send2log "updated $1 $2 $3 $4" -1
	$send2log "updated ul row-->$cur_hd" 0
	_thisHrdata=$(echo "$_thisHrdata" | sed -e "s~.\{0,\}\"$mac\".\{0,\}\"$hr\".\{0,\}~$cur_hd~Ig")
}
updateUsage()
{
	$send2log "updateUsage:  $1	$2" 0
	local cmd=$1
	local chain=$2
	local hr=$(date +%H)
	_ud_list=''
    local iptablesData=$(eval $cmd $_tMangleOption -nL "$chain" -vxZ | tr -s '-' ' ' | grep -vi RETURN | grep "^ [1-9]" | cut -d' ' -f3,8,9)
	if [ -z "$iptablesData" ] ; then
		$send2log ">>> $cmd returned no data... returning " -1
		return
	fi
	createUDList "$iptablesData"
	$send2log "iptablesData-->
$iptablesData" -1
	_ud_list=$(echo "$_ud_list" | tail -n+2)
	$send2log "_ud_list-->
$_ud_list" 0
	IFS=$'\n'
	for line in $_ud_list
	do
		[ -z "$line" ] && continue
		$send2log ">>> line-->$line" -1
		local ip=$(echo "$line" | cut -d',' -f1)
		local do=$(echo "$line" | cut -d',' -f2)
		local up=$(echo "$line" | cut -d',' -f3)
		update "$ip" "$do" "$up" "$hr"
	done
	unset IFS
}
updateUsage_0()
{ #update just IPv4 traffic
	$send2log "updateUsage_0" 0
	updateUsage 'iptables' "$YAMON_IP4"
}
updateUsage_1()
{ #update both IPv4 & IPv6 traffic
	$send2log "updateUsage_1" 0
	updateUsage 'iptables' "$YAMON_IP4"
	updateUsage 'ip6tables' "$YAMON_IP6"
}
updateHourly()
{
	fixHrly(){
		$send2log "Hourly data contains bad values... attempting to fix" 99
		$send2log "****** Bad _hourlyData ******
$_hourlyData" 1
		_hourlyData=$(echo "$_hourlyData" | sed -e "s~:,~:0,~g" | sed -e "s~:}~:0}~g" | sed -e "s~[0-9]\{23,\}~0~g" | grep -v "\"down\":0,\"up\":0")
	}
	local hr=$1
	[ -z "$hr" ] && hr=$(date +%H)
	$send2log "updateHourly [$hr]" 0
	local upsec=$(cat /proc/uptime | cut -d' ' -f1)
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	local hourlyHeader=$(getHourlyHeader "$upsec" "$ds")
	_thisHrpnd=$(getPND "$hr" "$upsec")
	_br_u=$(getCV "$_thisHrpnd" 'up')
	_br_d=$(getCV "$_thisHrpnd" 'down')
	$send2log "_hourlyData--> $_hourlyData" -1
	$send2log "_thisHrdata--> $_thisHrdata" 0
	$send2log "_pndData-> $_pndData" -1
	$send2log "_thisHrpnd-> $_thisHrpnd" 0
	[ -n "$(echo "$_hourlyData" | grep ":[,}]")" ] && fixHrly
	local nht="$_hourlyCreated
$hourlyHeader

$_hourlyData
$_thisHrdata

$_pndData
$_thisHrpnd"
	$save2File "$nht" "$_hourlyUsageDB"
}

runtimestats()
{
	$send2log "runtimestats $_totalhrRunTime $_hriterations" -1
	$send2log "arguments:  $1	$2" -1
	local start=$1
	local end=$2
	local runtime=$(($end-$start))
	#local offset=$(($end%$_updatefreq))
	_totalhrRunTime=$(($_totalhrRunTime + $runtime))
	_hriterations=$(($_hriterations + 1))
	_hr_rt_max=$(maxI $_hr_rt_max $runtime )
	_hr_rt_min=$(minI $_hr_rt_min $runtime )
	pause=$(($_updatefreq-$runtime>0?$_updatefreq-$runtime:0))
	$send2log ">>> #$_iteration - Execution time: $runtime seconds - pause: $pause seconds ($_hr_rt_min/$_hr_rt_max)" -1
	[ "$runtime" -gt "$_updatefreq" ] && $send2log "Execution time exceeded delay (${runtime}s)!" 2
}

# ==========================================================
#				  Main program
# ==========================================================

d_baseDir=$(cd "$(dirname "$0")" && pwd)
if [ ! -d "$d_baseDir/includes" ] || [ ! -f "$d_baseDir/includes/defaults.sh" ] ; then
	echo "
**************************** ERROR!!! ****************************
  You are missing the \`$d_baseDir/includes\` directory and/or
  files contained within that directory. Please re-download the
  latest version of YAMon and make sure that all of the necessary
  files and folders are copied to \`$d_baseDir\`!
******************************************************************
"
	exit 0
fi

source "${d_baseDir}/includes/versions.sh"
_configFile="$d_baseDir/config.file"
[ ! -f "$_configFile" ] && echo "$_s_noconfig" && exit 0
source "$_configFile"

source "${d_baseDir}/includes/defaults.sh"
source "$d_baseDir/includes/util$_version.sh"
source "$d_baseDir/strings/$_lang/strings.sh"

#globals
_logfilename=''
_devicesDB=""
_monthlyDB=""
_hourlyDB=""
_liveDB=""
_hourlyFile=""
_hourlyFile=""
_hourlyData=""
_hourlyCreated=''
_currentConnectedUsers=""
_hData=""
_unlimited_usage=0
_unlimited_start=""
_unlimited_end=""
_inUnlimited=0
_p_inUnlimited=0
_usersLastMod=''
_alertfilename=''
_totMem=''
_totalLostBytes=0
_changesInUsersJS=0
_hriterations=0
_liveusage=''
_ndAMS=0
_ndAMS_dailymax=24

started=0
sl_max=""
sl_max_ts=""
sl_min=""
sl_min_ts=""
_iteration=0
_br_d=''
_br_u=''
_p_ip4list=''
_p_ip6list=''

installedversion='tbd'
installedtype='tbd'

installedfirmware=$(uname -o)
if [ "$_has_nvram" -eq 1 ] ; then
	installedversion=$(nvram get os_version)
	installedtype=$(nvram get dist_type)
fi

np=$(ps | grep -v grep | grep -c yamon)
if [ -d "$_lockDir" ] ; then
	echo "$(ps | grep -v grep | grep yamon$_version)"
	echo "$_s_running" && exit 0
fi
[ -x /usr/bin/clear ] && clear
echo "$_s_title"
_cYear=$(date +%Y)
[ "$_cYear" -lt "2015" ] && echo "$_s_cannotgettime" && exit 0

_cDay=$(date +%d)
_pDay="$_cDay"
_cMonth=$(date +%m)

_ds="$_cYear-$_cMonth-$_cDay"
setInitValues
updateStaticLeases

# Set nice level of current PID to 10 (low priority)
if [ -n "$(which renice)" ] ; then 
	$send2log ">>> Setting \`renice\` level to 10 on PID: $$" 0
	renice 10 $$
else
	$send2log ">>> \`renice\` does not exist in this firmware" 0
fi

timealign=$(($_updatefreq-$(date +%s)%$_updatefreq))
$send2log ">>> Delaying ${timealign}s to align updates" 1
[ -n "$2" ] && sleep  "$timealign";
_p_hr=$(date +%H)
$send2log ">>> Starting main loop" 1

# Detach from terminal as suggested by yoyoma2
if [ "$_log2file" -eq "1" ] ; then
	exec 0>&- # close stdin
	exec 1>&- # close stdout
	exec 2>&- # close stderr 
fi

while [ 1 ]; do
	start=$(date +%s)

	checkTimes
	checkIPs
	$updateUsage
	$doliveUpdates

	_iteration=$(($_iteration%$_publishInterval + 1))
	if [ $(($_iteration%$_publishInterval)) -eq 0 ] ; then
		updateServerStats
		eval "checkChains_$_includeIPv6"
		checkConfig
		updateHourly
#
# ROOter
#
		/usr/lib/YAMon3/deldir.sh
#
	fi

	end=$(date +%s)
	runtimestats $start $end
	n=1
	while [ 1 ]; do
		[ ! -d "$_lockDir" ] && shutDown
		[ "$n" -gt "$pause" ] && break
		n=$(($n+1))
		sleep 1
	done
done &