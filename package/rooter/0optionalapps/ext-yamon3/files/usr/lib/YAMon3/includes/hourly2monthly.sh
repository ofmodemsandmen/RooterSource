##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# tally the hourly usage...
#
# 3.4.0 - substantial changes!
# 3.4.1 - added monthly totals
#
##########################################################################

#to do...
# auto delete log files if the disk is full...

calcMonthlyTotal()
{
	toGB()
	{
		local in_gb=$(awk "BEGIN {printf \"%.2f\",${1}/1024/1024/1024}")
		local units=''
		[ -z "$2" ] && units=' GB'
		echo "$in_gb$units"
	}
	updateInDB()
	{
		$send2log "=== updateInDB  === " 0
		$send2log "Arguments: $1 / $2" -1
		local inGB=$(toGB $2)
		local srch="var ${1}=.*"
		local repl="var ${1}=\"${2}\"	// $inGB"
		sed -i "s~$srch~$repl~ w /tmp/sed.txt" $_macUsageDB
		##[ -s /tmp/sed.txt ] && $send2log "Did not replace $1?!?" 2
		[ -s /tmp/sed.txt ] && return
		$send2log "Could not update $1... not found in $_macUsageDB?!?" 2
	}
	getULTotals()
	{
		$send2log "=== getULTotals  === " 0
		billed_down=$(digitSub "$mt_down" "$mt_ul_down")
		billed_up=$(digitSub "$mt_up" "$mt_ul_up")
	}
	getTotals_0()
	{
		IFS=$'\n'
		for line in $(echo "$dgtl")
		do	
			mt_down=$(digitAdd $mt_down $(getCV "$line" 'down'))
			mt_up=$(digitAdd $mt_up $(getCV "$line" 'up'))
		done
		unset IFS
	}
	getTotals_1()
	{
		IFS=$'\n'
		for line in $(echo "$dgtl")
		do	
			mt_down=$(digitAdd $mt_down $(getCV "$line" 'down'))
			mt_up=$(digitAdd $mt_up $(getCV "$line" 'up'))
			mt_ul_down=$(digitAdd $mt_ul_down $(getCV "$line" 'ul_do'))
			mt_ul_up=$(digitAdd $mt_ul_up $(getCV "$line" 'ul_up'))
		done
		unset IFS
	}
	$send2log "=== calcMonthlyTotal  === " 0
	$send2log "Arguments: $1" -1

	mud=$(cat "$1")
	vars=$(echo "$mud" | grep '^var')
	dgtl=$(echo "$mud" | grep '^dgt(')

	$send2log "vars: $vars" -1
	$send2log "dgtl: $dgtl" -1
	local mt_down=0
	local mt_up=0
	local mt_ul_down=0
	local mt_ul_up=0
	local billed_down=0
	local billed_up=0
	
	eval "getTotals_$_unlimited_usage"
	
	$send2log "mt_down: $mt_down
	mt_up: $mt_up
	mt_ul_down: $mt_ul_down
	mt_ul_up: $mt_ul_up
	" -1
	
	if [ -z "$(echo $vars | grep 'monthly_total')" ] ; then
		local rotf=$(echo "$mud" | grep -v '^var')
		local mt="var monthly_total_down=\"\"
var monthly_total_up=\"\""
		if [ "$_unlimited_usage" -eq "1" ] ;  then
			mt="$mt
var monthly_unlimited_down=\"\"
var monthly_unlimited_up=\"\"
var monthly_billed_down=\"\"
var monthly_billed_up=\"\""
		fi
		echo "$vars
$mt
$rotf" > $_macUsageDB
	fi

	updateInDB "monthly_total_down" "$mt_down"
	updateInDB "monthly_total_up" "$mt_up"
	
	if [ "$_unlimited_usage" -eq "1" ] ;  then
		getULTotals
		updateInDB "monthly_unlimited_down" "$mt_ul_down"
		updateInDB "monthly_unlimited_up" "$mt_ul_up"
		updateInDB "monthly_billed_down" "$billed_down"
		updateInDB "monthly_billed_up" "$billed_up"
	fi
	
	updateInDB "monthly_updated" "$(date +"%Y-%m-%d %H:%M:%S")"
	
	local mt_tot=$(digitAdd $mt_up $mt_down)
	local mt_tot_gb=$(toGB $mt_tot 0)
	mcap=$_monthlyDataCap
	[ "$mcap" -eq "0" ] && mcap=1000
	local cd=$(date -d "$_pYear-$_pMonth-$_pDay" +'%j')
	local pom=$(awk "BEGIN {printf \"%.4f\",($cd-$sd+1)/($ed-$sd+1)*100}")
	local au=$(awk "BEGIN {printf \"%.0f\",100*($mt_tot_gb/$mcap)}")
	local emu=$(awk "BEGIN {printf \"%.0f\",10000*($mt_tot_gb/$mcap)/$pom}")
	$send2log "mt_tot_gb: $mt_tot_gb ($mt_up + $mt_down)
	mcap: $mcap GB
	cd: $cd ($_pYear-$_pMonth-$_pDay)
	sd: $sd ($rYear-$rMonth-$rday)
	ed: $ed ($eYear-$eMonth-$eday
	pom: $pom%
	au: $au
	emu: $emu GB" 0
	[ "$au" -gt "$mcap" ] && $send2log "Usage has exceeded your monthly cap!!! used: $au GB / cap: $_monthlyDataCap GB" 99 && return
	[ "$_monthlyDataCap" -eq "0" ] && [ "$emu" -gt 1000 ] && $send2log "Expected monthly usage could exceed 1TB ($emu GB)" 99 && return
	[ "$_monthlyDataCap" -ne "0" ] && [ "$emu" -gt "$_monthlyDataCap" ] && $send2log "Expected monthly usage ($emu GB) could exceed your monthly cap of $_monthlyDataCap GB" 99 && return
	$send2log "Based upon usage to date, expected monthly total is ~$emu GB" 1 && return
}

updateHourly2Monthly()
{
	$send2log "=== updateHourly2Monthly === " 0
	
	setNewLine_0()
	{ 
		$send2log "=== setNewLine_0 === " 0
		echo "dt({\"mac\":\"$mac\",\"day\":\"$_pDay\",\"down\":$do_tot,\"up\":$up_tot})"
	}
	setNewLine_1()
	{ 
		$send2log "=== setNewLine_1 === " 0
		echo "dt({\"mac\":\"$mac\",\"day\":\"$_pDay\",\"down\":$do_tot,\"up\":$up_tot,\"ul_do\":$ul_do_tot,\"ul_up\":$ul_up_tot})"
	}
	getDGT_0()
	{ 
		$send2log "=== 	getDGT_0 === " 0
		echo "dgt({\"day\":\"$_pDay\",\"down\":$gt_down,\"up\":$gt_up})"
	}
	
	getDGT_1()
	{ 
		$send2log "=== getDGT_1 === " 0
		echo "dgt({\"day\":\"$_pDay\",\"down\":$gt_down,\"up\":$gt_up,\"ul_do\":$gt_ul_down,\"ul_up\":$gt_ul_up})"
	}
	
	tallyHourlyData_0()
	{	
		$send2log "=== tallyHourlyData_0 === " 0
		addUL_0()
		{
			$send2log "=== addUL_0  === " 0
			echo "$(setNewLine_0)"
		}
		
		addUL_1()
		{
			$send2log "=== addUL_1  === " 0
			ul_do_tot=$(digitAdd $(getCV "$curline" "ul_do") $(getCV "$line" "ul_do"))
			ul_up_tot=$(digitAdd $(getCV "$curline" "ul_up") $(getCV "$line" "ul_up"))

			if [ "$ul_do_tot" \< "0" ] ; then
				$send2log ">>> ul_do_tot rolled over --> $ul_do_tot" 0
				ul_do_tot=$(digitSub "$_maxInt" "$ul_do_tot")
			fi
			if [ "$ul_up_tot" \< "0" ] ; then
				$send2log ">>> ul_up_tot rolled over --> $ul_up_tot" 0
				ul_up_tot=$(digitSub "$_maxInt" "$ul_up_tot")
			fi
			gt_ul_down=$(digitAdd $gt_ul_down $ul_do_tot)
			gt_ul_up=$(digitAdd $gt_ul_up $ul_up_tot)
			echo "$(setNewLine_1)"
		}
		
		#old method, without uniq & sort
		local mac=''
		local hr=''
		local linematch=''
		local curline=''
		local woline=''
		local do_tot=0
		local up_tot=0
		local ul_do_tot=0
		local ul_up_tot=0
		local gt_down=0
		local gt_up=0
		local gt_ul_down=0
		local gt_ul_up=0
		local down=0
		local up=0

		IFS=$'\n'
		for line in $(echo "$hrlyData" | grep "^hu")
		do
			[ -z "$showProgress" ] || echo -n '.' >&2
			$send2log "line-->$line" 0
			mac=$(getField "$line" 'mac')
			mac=$(echo $mac | tr 'A-Z' 'a-z')
			hr=$(getField "$line" "hour")
			if [ -z "$mac" ] ; then
				$send2log "MAC is null?!?	$line" 2
				continue;
			fi
			linematch="dt({\"mac\":\"$mac\",\"day\":\"$_pDay\""
			curline=$(echo "$hr_results" | grep -i "$linematch")
			woline=$(echo "$hr_results" | grep -iv "$linematch")
			$send2log "curline-->$curline" -1

			down=$(getCV "$line" "down")
			up=$(getCV "$line" "up")
			do_tot=$(digitAdd $(getCV "$curline" "down") $down)
			up_tot=$(digitAdd $(getCV "$curline" "up") $up)

			gt_down=$(digitAdd $gt_down $down)
			gt_up=$(digitAdd $gt_up $up)

			if [ "$do_tot" \< "0" ] ; then
				$send2log ">>> do_tot rolled over --> $do_tot" 0
				do_tot=$(digitSub "$_maxInt" "$do_tot")
			fi
			if [ "$up_tot" \< "0" ] ; then
				$send2log ">>> up_tot rolled over --> $up_tot" 0
				up_tot=$(digitSub "$_maxInt" "$up_tot")
			fi
			newline="$(eval "addUL_$_unlimited_usage")"
			$send2log "newline-->$newline" -1
			hr_results="$woline
$newline"
		done
		[ -z "$showProgress" ] || echo '' >&2
		unset IFS

		dgt=$(eval $dgt_fn)
		hr_results="$hr_results
			
$dgt"

	}
	
	tallyHourlyData_1()
	{	#new method, with uniq & sort
		$send2log "=== tallyHourlyData_1  === " 0
	
		macTotals_0()
		{
			$send2log "=== macTotals_0  === " 0
			for line in $(echo "$macEntries") 
			do
				$send2log "line: $line" -1
				do_tot=$(digitAdd $do_tot $(getCV "$line" 'down'))
				up_tot=$(digitAdd $up_tot $(getCV "$line" 'up') )
			done
			newline=$(setNewLine_0)
			hr_results="$hr_results
$newline"
		}

		macTotals_1()
		{
			$send2log "=== macTotals_1  === " 0
			$send2log "macEntries: $macEntries" -1
			for line in $(echo "$macEntries") 
			do
				do_tot=$(digitAdd $do_tot $(getCV "$line" 'down'))
				up_tot=$(digitAdd $up_tot $(getCV "$line" 'up'))
				ul_do_tot=$(digitAdd $ul_do_tot $(getCV "$line" 'ul_do'))
				ul_up_tot=$(digitAdd $ul_up_tot $(getCV "$line" 'ul_up'))
			done
			gt_ul_down=$(digitAdd $gt_ul_down $ul_do_tot)
			gt_ul_up=$(digitAdd $gt_ul_up $ul_up_tot)
			
			echo "gt_ul_down: $gt_ul_down" &>2

			newline=$(setNewLine_1)
			hr_results="$hr_results
$newline"
		}
		
		local hrlyData=$(echo "$hrlyData" | grep "^hu")
		$send2log "hrlyData: $hrlyData " -1
		local macList=$(echo "$hrlyData" | grep -o "\"mac\":\"[^\"]\{1,\}\"" | tr 'A-Z' 'a-z'| sort -k1| uniq -c | cut -d'"' -f4)
		$send2log "macList: $macList " -1
		IFS=$'\n'
		local gt_down=0
		local gt_up=0
		local gt_ul_down=0
		local gt_ul_up=0
		for mac in $(echo "$macList")
		do
			[ -z "$showProgress" ] || echo -n '.' >&2
			local down=0
			local up=0
			local do_tot=0
			local up_tot=0
			local ul_do_tot=0
			local ul_up_tot=0
			local macEntries=$(echo "$hrlyData" | grep -i $mac)

			eval "macTotals_"$_unlimited_usage

			gt_down=$(digitAdd $gt_down $do_tot )
			gt_up=$(digitAdd $gt_up $up_tot )

		done
		
		dgt=$(eval $dgt_fn)
		hr_results="$hr_results
			
$dgt"

	}
	
	$send2log "=== updateHourly2Monthly === " 0
	_pYear=$1
	_pMonth=$2
	_pDay=$3
	_pMonth=${_pMonth#0}
	local rMonth=${_pMonth#0}
	local eMonth=${_pMonth#0}
	local rYear=$_pYear
	local eYear=$_pYear
	local rday=$(printf %02d $_ispBillingDay)
	local eday=$(printf %02d $(($_ispBillingDay-1)))

	if [ "$_pDay" -lt "$_ispBillingDay" ] ; then
		rMonth=$(($rMonth-1))
		if [ "$rMonth" == "0" ] ; then
			rMonth=12
			rYear=$(($rYear-1))
		fi
	else
		eMonth=$(($_pMonth+1))
		if [ "$eMonth" == "13" ] ; then
			eMonth=1
			eYear=$(($eYear+1))
		fi
	fi
	_pMonth=$(printf %02d $_pMonth)
	rMonth=$(printf %02d $rMonth)
	eMonth=$(printf %02d $(($eMonth)))
	sd=$(date -d "$rYear-$rMonth-$rday" +'%j')
	ed=$(date -d "$eYear-$eMonth-$eday" +'%j')

	if [ "${_dataDir:0:1}" == "/" ] ; then
		local _dataPath=$_dataDir
	else
		local _dataPath="${d_baseDir}/$_dataDir"
	fi
	case $_organizeData in
		(*"0"*)
			local savePath="$_dataPath"
		;;
		(*"1"*)
			local savePath="$_dataPath$rYear/"
		;;
		(*"2"*)
			local savePath="$_dataPath$rYear/$rMonth/"
		;;
	esac
	#_macUsageDB="$savePath$rYear-$rMonth-$rday-$_usageFileName"
	_macUsageDB="$savePath$rYear-$rMonth-$_usageFileName"
	[ "$_enable_ftp" -eq "1" ] && _macUsageFTP="$_cYear-$_cMonth-$_cDay-$_usageFileName"

	local _prevhourlyUsageDB="$savePath$_pYear-$_pMonth-$_pDay-$_hourlyFileName"
	if [ ! -f "$_prevhourlyUsageDB" ]; then
		$send2log "*** Hourly usage file not found ($_prevhourlyUsageDB)  (_organizeData:$_organizeData)" 1
		return
	fi
	local pnd_results=''
	local p_do_tot=0
	local p_up_tot=0
	local _maxInt="4294967295"
	local hrlyData=$(cat "$_prevhourlyUsageDB")
	$send2log "hrlyData: $hrlyData" -1
	$send2log ">>> reading from $_prevhourlyUsageDB & writing to $_macUsageDB" 0

	local pnd=$(echo "$hrlyData" | grep "^pnd")
	local start=$(echo "$pnd" | grep -i '"start"')
	$send2log "Start: $start" 0
	local p_uptime=0
	local guest_str=''
	local t_do=0
	local t_up=0
	local nreboots=0
	local s_uptime=$(getCV "$start" "uptime")
	local p_uptime=$s_uptime
	local s_d=$(getCV "$start" "down")
	local s_u=$(getCV "$start" "up")
	if [ ! "$_guest_iface" == '' ] ; then
		local s_gd=$(getCV "$start" "guest-down")
		local s_gu=$(getCV "$start" "guest-up")
		local guest_str=" / guest-down: $s_gd / guest-up: $s_gu"
		local t_gdo=0
		local t_gup=0
	fi

	$send2log "uptime: $s_uptime / down: $s_d / up: $s_u $guest_str" -1

	IFS=$'\n'
	for line in $(echo "$pnd" | grep -v "\"start\"")
	do
		c_uptime=$(getCV "$line" "uptime")
		c_u=$(echo $c_uptime | cut -d. -f1)
		p_u=$(echo $p_uptime | cut -d. -f1)
		if [ "$c_u" -gt "$p_u" ] ; then
			p_uptime=$c_uptime
			p_line=$line
			continue
		else
			$send2log "reboot: $nreboots" -1
			nreboots=$(($nreboots + 1))

			s_uptime=$c_uptime
			c_d=$(getCV "$p_line" "down")
			c_u=$(getCV "$p_line" "up")
			t_do=$(( $t_do + $c_d - $s_d  ))
			t_up=$(( $t_up + $c_u - $s_u  ))
			s_d=0
			s_u=0
			t_guest=''
			if [ ! "$_guest_iface" == '' ] ; then
				c_gd=$(getCV "$p_line" 'guest-down')
				c_gu=$(getCV "$p_line" 'guest-up')
				t_gdo=$(( $t_gdo + $c_gd - $s_gd  ))
				t_gup=$(( $t_gup + $c_gu - $s_gu  ))
				s_gd=0
				s_gu=0
				t_guest=" / t_gdo: $t_gdo / t_gup: $t_gup"
			fi
			$send2log "t_do: $t_do / t_up: $t_up $t_guest" 0
		fi
		p_uptime=$c_uptime
		p_line=$line
	done
	$send2log "Last line: $p_line" 0
	c_d=$(getCV "$p_line" "down")
	c_u=$(getCV "$p_line" "up")
	t_do=$(( $t_do + $c_d - $s_d  ))
	t_up=$(( $t_up + $c_u - $s_u  ))
	if [ ! "$_guest_iface" == '' ] ; then
		c_gd=$(getCV "$p_line" 'guest-down')
		c_gu=$(getCV "$p_line" 'guest-up')
		t_gdo=$(( $t_gdo + $c_gd - $s_gd  ))
		t_gup=$(( $t_gup + $c_gu - $s_gu  ))
		t_guest=",\"guest-down\":$t_gdo,\"guest-up\":$t_gup"
	fi

	pnd_results="dtp({\"day\":\"$_pDay\",\"down\":$t_do,\"up\":$t_up$t_guest,\"reboots\":$nreboots})"
	save2File "$pnd_results" "$_macUsageDB" "append"

	local hr_results=''
	local ddd=$(date)
	[ -z "$showProgress" ] || echo -n "    $_pDay --> Hourly: " >&2

	dgt_fn="getDGT_$_unlimited_usage"
	eval "$tallyHourlyData"
	[ -z "$showProgress" ] || echo '' >&2
	save2File "$hr_results" "$_macUsageDB" "append"
	[ -z "$just" ] && calcMonthlyTotal "$_macUsageDB"
	
	$send2log "=== done updateHourly2Monthly === " 0
}