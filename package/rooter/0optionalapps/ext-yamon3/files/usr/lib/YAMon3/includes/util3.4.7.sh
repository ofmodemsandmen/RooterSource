##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# various utility functions (shared between one or more scripts)
#
# History
# 3.3.0 (2017-06-18): bumped minor version; added xwrt
# 3.3.1 (2017-07-17): general housekeeping; updated checkIPChain & getMACIPList; removed unused send2DB
# 3.3.3 (2017-09-25): cleaned up d_baseDir; optionally backup _liveArchiveFilePath in dailyBU()
# 3.4.3 (2018-02-26): added topics to prompt links
# 3.4.6 (2019-01-22): no changes - version number updated for consistency
#
##########################################################################

[ -z "$_enableLogging" ] && _enableLogging=0
[ -z "$_log2file" ] && _log2file=1
[ -z "$_scrlevel" ] && _scrlevel=1
[ -z "$_loglevel" ] && _loglevel=0

log() {
	logger -t "YAMon 3 Setconfig : " "$@"
}

showmsg()
{
	local wm=$1
	$send2log "showmsg:  $1" -1
	msg="$(cat "$d_path2strings$wm" )"
	[ -n "$2" ] && msg=$(echo "$msg" | sed -e "s~\%1\%~$2~g" )
	[ -n "$3" ] && msg=$(echo "$msg" | sed -e "s~\%2\%~$3~g" )
	[ -n "$4" ] && msg=$(echo "$msg" | sed -e "s~\%3\%~$4~g" )
	echo  "$msg"
}

prompt()
{
	local resp
	local vn=$1
	eval nv=\"\$$vn\"
	local df="$4"
	local regex="$5"
	_qn=$(($_qn + 1))
	local p2="$2"
	local topic="$6"
	[ -z  "$topic" ] && topic="$vn"
	echo -e "
#$_qn. $p2" >&2
	p3="$(echo -e "    $3
	"| sed -re 's~[\t]+~    ~g')
    "
	if [ -z "$nv" ] && [ -z "$df" ] ; then
		nv='n/a'
		df='n/a'
		readStr="    Enter your preferred value: "
	elif [ -z "$df" ] ; then
		readStr="${p3}Hit <enter> to accept the current value (\`$nv\`),
      or enter your preferred value: "
	elif [ -z "$nv" ] ; then
		nv='n/a'
		readStr="${p3}Hit <enter> to accept the default (\`$df\`),
      or enter your preferred value: "
	elif [ "$df" == "$nv" ] ; then
		readStr="${p3}Hit <enter> to accept the current/default value (\`$df\`),
      or enter your preferred value: "
	else
		readStr="${p3}Hit <enter> to accept the current value: \`$nv\`, \`d\` for the default (\`$df\`)
      or enter your preferred value: "
	fi

	local tries=0
	while true; do
		read -p "$readStr" resp
		[ ! "$df" == 'n/a' ] && [ "$resp" == 'd' ] && resp="$df" && rt="accepted default" && break
		[ ! "$nv" == 'n/a' ] && [ -z "$resp" ] && resp="$nv" && rt="accepted current" && break
		[ "$nv" == 'n/a' ] && [ ! "$df" == 'n/a' ] && [ -z "$resp" ] && resp="$df" && rt="accepted default" && break
		if [ -n "$regex" ] ;  then
			ig=$(echo "$resp" | grep -E $regex)
			[ ! "$ig" == '' ] && [ "$resp" == 'n' ] || [ "$resp" == 'N' ] && resp="0" && rt="typed 0" && break
			[ ! "$ig" == '' ] && [ "$resp" == 'y' ] || [ "$resp" == 'Y' ] && resp="1" && rt="typed 1" && break
			[ ! "$ig" == '' ] && rt="typed $resp" && break
		else
		    rt="else" 
			break
		fi
		tries=$(($tries + 1))
		if [ "$tries" -eq "3" ] ; then
			echo "*** Strike three... you're out!" >&2
			exit 0
		fi
		$send2log "Bad value for $vn --> $resp" 1
		echo "
    *** \`$resp\` is not a permitted value for this variable!  Please try again.
     >>> For more info, see http://usage-monitoring.com/help/?t=$topic" >&2
	done
	eval $vn=\"$resp\"
	updateConfig $vn "$resp" "$rt"
}
updateConfig(){
	#log "updateConfig:  $1	$2	$3" 0
	local vn=$1
	local nv=$2
	#echo "	  $vn --> $nv	($rt)" >> $_logfilename
	[ "${vn:0:2}" == 't_' ] && return
	[ -z "$nv" ] && eval nv="\$$vn"
	local sv="$vn=.*#"
	local rv="$vn=\'$nv\'"
	local sm=$(echo "$configStr" | grep -o $sv)
	local l1=${#sm}
	local l2=${#rv}
	#echo "updateConfig: sm--> $sm ($l1)// rv--> $rv ($l2)" >&2
	local spacing='==================================================='
	if [ -z "$sm" ] ; then
		local pad=${spacing:0:$((55-$l2+1))}
		pad=${pad//=/ }
		configStr="$configStr
$vn='$nv'$pad # Added"
	#log "updateConfig: $vn='$nv'$pad# Added" >&2
	else
		local pad=${spacing:0:$((55-$l2+1))}
		pad=${pad//=/ }
		configStr=$(echo "$configStr" | sed -e "s~$sv~$rv$pad#~g")
	fi
	#log "updateConfig: configStr--> $configStr" >&2
}
getDefault(){
	$send2log "getDefault:  $1	$2" 0
	eval vv=\$"options$1"
	local rv=$(echo "$vv" | cut -d, -f$(($2+1)))
	[ -z "$rv" ] && rv=$(echo "$vv" | cut -d, -f1)
	echo "$rv"
}
copyfiles(){
	$send2log "copyfiles:  $1	$2" 0
	local src=$1
	local dst=$2
	$(cp -a $src $dst)
	local res=$?
	if [ "$res" -eq "1" ] ; then
		local pre='  !!!'
		local pos=' failed '
	else
		local pre='  >>>'
		local pos=' successful'
	fi
	local lvl=$(($res+1))
	$send2log "$pre Copy from $src to $dst$pos ($res)" $lvl
}
copyfiles_0()
{	#_symlink2data=0
	$send2log "copyfiles_0:  $1	$2" 0
	copyfiles "$1" "$2"
}
copyfiles_1()
{	#_symlink2data=1
	return
}
send2log_0()
{	#_enableLogging=0
	return
}
alertfile(){
	local msg="$(echo "$1" | sed "s~[^a-z0-9\.\-\/:_\t ]~~ig" | tr '\n' '+')"
	local ts=$(date +"%Y-%m-%d %H:%M:%S")

	local srch=$(cat "$_alertfilename" | grep -i "$msg")
	[ -z "$srch" ] && echo "y_a({\"first\":\"$ts\",\"last\":\"$ts\",\"count\":\"1\",\"msg\":\"$msg\"})" >> $_alertfilename && return
	local first=$(getField "$srch" "first")
	local count=$(getField "$srch" "count")
	[ -z "$first" ] && first="$ts"
	[ -z "$count" ] && count=0
	count=$(($count + 1))
	
	local repl="y_a({\"first\":\"$first\",\"last\":\"$ts\",\"count\":\"$count\",\"msg\":\"$msg\"})"
	sed -i "s~$srch~$repl~ w /tmp/afn.txt" $_alertfilename
	
	[ "$2" -eq "99" ] && $sendAlert "YAMon Alert..." "$1"

}
send2log_1_0()
{	#_enableLogging=1 & _log2file=0 (screen only)
	[ "$2" -lt "$_scrlevel" ] && return
	local ts=$(date +"%Y-%m-%d %H:%M:%S")
	echo -e "$1" >&2
	[ "$2" -ge "2" ] && alertfile "$1" "$2"
}
send2log_1_1()
{	#_enableLogging=1 & _log2file=1 (file only)
	[ "$2" -lt "$_loglevel" ] && return
	local ts=$(date +"%H:%M:%S")
	echo -e "$ts\t$2\t$1" >> $_logfilename
	[ "$2" -ge "2" ] && alertfile "$1" "$2"
}
send2log_1_2()
{	#_enableLogging=1 & _log2file=2 (both file & screen)
	local ts=$(date +"%H:%M:%S")
	[ "$2" -ge "$_loglevel" ] && echo -e "$ts\t$2\t$1" >> $_logfilename
	[ "$2" -ge "$_scrlevel" ] && echo -e "$ts $2 $1" >&2
	[ "$2" -ge "2" ] && alertfile "$1" "$2"
}
send2log()
{
	[ "$_enableLogging" -eq "0" ] && return
	[ ! -f "$_logfilename" ] && echo "no log file: $1" && return

	local ll=$2
	[ -z "$ll" ] && ll=0
	local ts=$(date +"%H:%M:%S")
	[ "$_sendAlerts" -gt "0" ] && [ "$ll" -eq "99" ] && sendAlert "YAMon Alert..." "$1"
	[ "$_log2file" -ge "1" ] && [ "$ll" -ge "$_loglevel" ] && echo "$ts\t$ll\t$1" >> $_logfilename
	[ "$_log2file" -ne "1" ] && [ "$ll" -ge "$_scrlevel" ] && echo "$ts $ll $1" >&2
}

sendAlert_0()
{
	return
}
sendAlert_1()
{
	$send2log "sendAlert:  $1	$2" 0
	local subj="$1"
	local omsg="$2"
	[ -z "$ndAMS" ] && ndAMS=0
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	msg="$omsg \n\n Message sent: $ds"
	if [ "$ndAMS" -eq "$_ndAMS_dailymax" ] ; then
		$send2log "sendAlert:: reached daily alerts max... cannot send subj: $subj  msg: $omsg" 2
		subj="Please check your YAMon Settings!"
		msg="You have reached your maximum alerts allocation (max $_ndAMS_dailymax messages per day).  This typically means that there is something wrong in your settings or configuration.  Please contact Al if you have any questions."
	elif [ "$ndAMS" -gt "$_ndAMS_dailymax" ] ; then
		$send2log "sendAlert:: exceeded daily alerts max... cannot send subj: $subj  msg: $omsg" 0
		return
	fi
	if [ "$_sendAlerts" -eq "1" ] ; then
		subj=${subj//\'/`}
		msg=${msg//\'/`}
		local url="http://usage-monitoring.com/current/sendmail.php"
		if [ -n "$(which curl)" ] ; then
			curl -G -sS "$url" --data-urlencode "t=$_sendAlertTo" --data-urlencode "s=$subj" --data-urlencode "m=$msg"  > /tmp/sndm.txt
		else
			url="$url?t=$_sendAlertTo&s=$subj&m=$msg"
			local url=${url// /%20}
			wget "$url" -U "YAMon-Setup" -qO "/tmp/sndm.txt"
		fi
		local res=$(cat /tmp/sndm.txt)
	elif [ "$_sendAlerts" -eq "2" ] ; then
		ECHO=/bin/echo
		$ECHO -e "Subject: $subj\n\n$msg\n\n" | $_path2MSMTP -C $_MSMTP_CONFIG -a gmail $_sendAlertTo
		$send2log "calling sendAlert via msmtp - subj: $subj  msg: $msg" 2
	fi
	ndAMS=$(($ndAMS+1))
}
setWebDirectories()
{
	addSymLink()
	{
		local src=${1//\/\//\/}
		local dest=${2//\/\//\/}
		$send2log "addSymLink: $src --> $dest" 0
		[ -h "$dest" ] && rm -fv "$dest"
		ln -s "$src" "$dest"
	}
	$send2log "setWebDirectories" 0
	if [ ! -d "$_wwwPath" ] ; then
		mkdir -p "$_wwwPath"
		chmod -R a+rX "$_wwwPath"
	fi
	#fix recommended by Jeff Park
	local l_wp=${_wwwPath%/}
	local l_www="/${_webDir%/}/${_wwwURL%/}"
	l_www=${l_www//\/\//\/}
	if [ -e "$l_www" ] ; then
		$send2log "Path found OK for $l_www --> no link needed" 1
	else
	    ln -s "$l_wp" "$l_www"
		$send2log "Symbolic Link created --> $l_www to $l_wp" 1
	fi

	[ -d "$l_wp/$_wwwJS" ] || mkdir -p "$l_wp/$_wwwJS"
	if [ "$_symlink2data" -eq "1" ] ; then
		local lcss=${_wwwCSS%/}
		local limages=${_wwwImages%/}
		local ldata=${_wwwData%/}

		addSymLink "${d_baseDir}/$_webDir/$lcss" "$l_wp/$lcss"
		addSymLink "${d_baseDir}/$_webDir/$limages" "$l_wp/$limages"
		addSymLink "${_dataPath%/}" "$l_wp/$ldata"
		addSymLink "${d_baseDir}/$_webDir/$d_webIndex" "$l_wp/$_webIndex"
		addSymLink "${d_baseDir}/$_webDir/$_wwwJS/$_configWWW" "$l_wp/$_wwwJS/$_configWWW"

		[ -z "$routerfile" ] && routerfile="${d_baseDir}/${_webDir}/${_wwwJS}/router.js"
		routerfile=${routerfile//\/\//\/}
		addSymLink "$routerfile" "$l_wp/${_wwwJS}/router.js"
	elif [ "$_symlink2data" -eq "0"  ] ; then
		copyfiles "${d_baseDir}/$_webDir*" "$l_wp/"
	fi

	if [ "$_firmware" -eq "1" ] || [ "$_firmware" -eq "4" ] || [ "$_firmware" -eq "6" ] || [ "$_firmware" -eq "7" ] ; then
		local lan_ip=$(uci get network.lan.ipaddr)
		[ -z "$lan_ip" ] && lan_ip=$(ifconfig br-lan | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
	else
		local lan_ip=$(nvram get lan_ipaddr)
	fi
	
	if [ "$_enable_ftp" -eq 1 ] ; then
		[ -f "$routerfile" ] && send2FTP "$routerfile"
		send2FTP "${d_baseDir}/$_webDir/$d_webIndex"
	fi
	local reports="${lan_ip}$_wwwURL/$_webIndex"
	reports="http://${reports//\/\//\/}"
	echo "

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ~  Your reports URL: $reports
    ~  (subject to some firmware variant oddities)
    ~  If your reports do not open properly, see
    ~     http://usage-monitoring.com/help/?t=reports-help
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	$send2log "Reports URL: $reports" 1
	$send2log "Paths:
$(ls -la $_wwwPath)" 0
}
getField()
{	#returns just the first match... duplicates are ignored
	local result=$(echo "$1" | grep -o -m1 "$2\":\"[^\"]\{1,\}" | cut -d\" -f3)
	echo "$result"
	$send2log "getField: $1 / $2=$result" 0
	[ -z "$result" ] && $send2log "field '$2' not found in '$1'" -1
}
getCV()
{	#returns just the first match... duplicates are ignored
	local result=$(echo "$1" | grep -io -m1 "\"$2\":[\"0-9]\{1,\}" | grep -o "[0-9]\{1,\}");
	echo "$result"
	$send2log "getCV: $1 / $2=$result" 0
	[ -z "$result" ] && result=0 && $send2log "field '$2' not found in '$1'... set to 0" -1
}
replace()
{
	local line=$1
	local srch="\"$2\":\"[^\"]*\""
	local rplc="\"$2\":\"$3\""
	$send2log "srch: $srch
	rplc: $rplc" -1
	local result=$(echo $line | sed -e "s~$srch~$rplc~Ig" )
	echo "$result"
	$send2log "replace:  $1  $2  $3 / $2=$result " 0
	[ -z "$result" ] && $send2log "field '$2' not found in '$1'" -1
}
replaceNum()
{
	local line=$1
	local srch="\"$2\":[0-9]*"
	local rplc="\"$2\":$3"
	local result=$(echo $line | sed -e "s~$srch~$rplc~Ig" )
	echo "$result"
	$send2log "replaceNum: $1 $2 $3 / $2=$result " 0
	[ -z "$result" ] && $send2log "field '$2' not found in '$1'" -1
}
dailyBU()
{
	$send2log "Daily Backups:  $1  $2  $3" 0
	local bupath=$_dailyBUPath
	[ ! "${_dailyBUPath:0:1}" == "/" ] && bupath="${d_baseDir}/$_dailyBUPath"

	if [ ! -d "$bupath" ] ; then
		$send2log ">>> Creating Daily BackUp directory - $bupath" 0
		mkdir -p "$bupath"
	fi
	local manifest="/tmp/manifest.txt"
	[ -f "$manifest" ] && touch "$manifest"
	local bu_ds=$1
	echo "$bu_ds
_usersFile: $_usersFile
_macUsageDB: $_macUsageDB
_hourlyUsageDB: $_hourlyUsageDB" > "$manifest"
	if [ "$_tarBUs" -eq "1" ]; then
		echo "logfilename: $_logfilename" >> "$manifest"
		$send2log ">>> Compressed back-ups for $bu_ds to $bupath"'bu-'"$bu_ds.tar" 0
		local bp="${bupath}bu-$bu_ds.tar"
		if [ "$_enableLogging" -eq "1" ] ; then
			tar -czf "$bp" "$manifest" "$_usersFile" "$_macUsageDB" "$_hourlyUsageDB" "$_logfilename" &
		else
			tar -czf "$bp" "$manifest" "$_usersFile" "$_macUsageDB" "$_hourlyUsageDB" &
		fi
		local return=$?
		if [ "$return" -ne "0" ] ; then
			$send2log ">>> Back-up compression for $bu_ds failed! Tar returned $return" 2
		else
			$send2log ">>> Back-ups for $bu_ds compressed - tar exited successfully." 0
		fi
	else
		local budir="$bupath"'bu-'"$bu_ds/"
		$send2log ">>> Copy back-ups for $bu_ds to $budir" 1
		[ ! -d "$bupath"'/bu-'"$bu_ds/" ] && mkdir -p "$budir"
		copyfiles "$_usersFile" "$budir"
		copyfiles "$_macUsageDB" "$budir"
		copyfiles "$_hourlyUsageDB" "$budir"
		[ "$_doArchiveLiveUpdates" -eq "1" ] && copyfiles "$_liveArchiveFilePath" "$budir"
		[ "$_enableLogging" -eq "1" ] && copyfiles "$_logfilename" "$budir"
	fi
}
add2UDList(){
	$send2log "add2UDList:  $1  $2  $3" 0
	local ip=$1
	local do=$2
	local up=$3
	local le=$(echo "$_ud_list" | grep -i "\b$ip\b")
	$send2log "le-->$le" -1
	if [ -z "$le" ] ; then
		_ud_list="$_ud_list
$ip,$do,$up"
	else
		local pd=$(echo $le | cut -d',' -f2)
		local pu=$(echo $le | cut -d',' -f3)
		do=$(digitAdd "$do" "$pd")
		up=$(digitAdd "$up" "$pu")
		local tip=${ip//\./\\.}
		_ud_list=$(echo "$_ud_list" | sed -e "s~^$tip\b.*~$ip,$do,$up~Ig")
	fi
}
createUDList(){
	$send2log "createUDList:  $1" -1
	local results=''
	local itd="$1"
	IFS=$'\n'
	for line in $itd
	do
		$send2log ">>> line-->$line" -1
		local f1=$(echo "$line" | cut -d' ' -f1)
		local f2=$(echo "$line" | cut -d' ' -f2)
		local f3=$(echo "$line" | cut -d' ' -f3)
		local isy=$(echo "$f1" | grep -i 'yamon')
		[ -n "$isy" ] && continue
		[ "$f1" -eq '0' ] && continue
		$send2log ">>> f1-->$f1	f2-->$f2   f3-->$f3   " -1
		if [ "$f2" == "$_generic_ipv4" ] || [ "$f2" == "$_generic_ipv6" ] ; then
			add2UDList $f3 $f1 0
		else
			add2UDList $f2 0 $f1
		fi
	done
	unset IFS
}
maxF(){
	$send2log "maxF:  $1	$2" -1
	[ -z "$1" ] && [ -z "$2" ] && echo 0 && return
	[ -z "$1" ] && echo $2 && return
	[ -z "$2" ] && echo $1 && return
	[ "$1" \> "$2" ] && echo $1 && return
	echo $2
}
minF(){
	$send2log "minF:  $1	$2" -1
	[ -z "$1" ] && [ -z "$2" ] && echo 0 && return
	[ -z "$1" ] && echo $2 && return
	[ -z "$2" ] && echo $1 && return
	[ "$1" \< "$2" ] && echo $1 && return
	echo $2
}
maxI(){
	$send2log "maxI:  $1	$2" -1
	[ -z "$1" ] && [ -z "$2" ] && echo 0 && return
	[ -z "$1" ] && echo $2 && return
	[ -z "$2" ] && echo $1 && return
	[ "$1" -gt "$2" ] && echo $1 && return
	echo $2
}
minI(){
	$send2log "minI:  $1	$2" -1
	[ -z "$1" ] && [ -z "$2" ] && echo 0 && return
	[ -z "$1" ] && echo $2 && return
	[ -z "$2" ] && echo $1 && return
	[ "$1" -lt "$2" ] && echo $1 && return
	echo $2
}

checkIPTableEntries()
{
	clearIPs(){
		$send2log "clearIPs:  $1	$2	$3" 0
		local cmd=$1
		local chain=$2
		local ip=$3
		#[ "$ip" == "$g_ip" ] && return
		while [ true ]; do
			local dup_num=$(eval $cmd $_tMangleOption -vnxL "$chain" --line-numbers | grep -m 1 -i "\b$ip\b" | cut -d' ' -f1)
			[ -z "$dup_num" ] && break
			eval $cmd $_tMangleOption  -D "$chain" $dup_num
		done
	} 
	addIP(){
		$send2log "addIP:  $1	$2	$3 --> $gn" 0
		local cmd=$1
		local chain=$2
		local ip=$3
		if [ "$ip" == "$g_ip" ] ; then
			[ "$_logNoMatchingMac" -eq "1" ] && eval $cmd $_tMangleOption -A "$chain" -s "$ip" -j LOG --log-prefix "YAMon: "
			eval $cmd $_tMangleOption -A"$chain" -s "$ip" -j RETURN
			#iptables -A LOGGING -m limit --limit 2/min -j LOG --log-prefix "IPTables-Dropped: " --log-level 4

		#elif [ "$cmd" == 'iptables' ] ; then
		#	eval $cmd $_tMangleOption -I "$chain" -s "$ip" -g $gn
		#	eval $cmd $_tMangleOption -I "$chain" -d "$ip" -g $gn
		else
			ip=${ip/ (dup)/}
			eval $cmd $_tMangleOption -I "$chain" -s "$ip" -j RETURN
			eval $cmd $_tMangleOption -I "$chain" -d "$ip" -j RETURN
			eval $cmd $_tMangleOption -I "$chain" -s "$ip" -j $gn
			eval $cmd $_tMangleOption -I "$chain" -d "$ip" -j $gn
		fi
	}

	$send2log "checkIPTableEntries:  $1	$2	$3	$4" 0

	cmd=$1
	chain=$2
	ip=$3
	mac=$4
	
	g_ip="$_generic_ipv4"
	[ "$cmd" == 'ip6tables' ] && g_ip="$_generic_ipv6"
	
	local tip=${ip//\./\\.}
	if [ "$ip" == "$g_ip" ] ; then
		local nm=$(eval $cmd $_tMangleOption -vnxL "$chain" | tr -s ' ' | grep -c "$g_ip $g_ip")
		[ "$nm" -eq "1" ] || [ "$nm" -eq "2" ] && return
	else
		local nm=$(eval $cmd $_tMangleOption -vnxL "$chain" | grep -ic "$tip\b")
		[ "$nm" -eq "2" ] || [ "$nm" -eq "4" ] && return
	fi
	
	local line=$(echo "$_currentUsers" | grep -i "\b$mac\b")
	local gp=$(echo $(getField "$line" 'owner') | sed "s~[^a-z0-9]~~ig")
	[ -z "$gp" ] && gp='Unknown'
	local gn="${chain}_gp_$gp"
	if [ -z "$(eval $cmd $_tMangleOption -nL -vx | grep -i "chain $gn")" ] ; then
		$send2log "Adding group chain to iptables: $gn  " 2
		eval $cmd $_tMangleOption -N "$gn"
		eval $cmd $_tMangleOption -A "$gn" -j "RETURN" -s $g_ip -d $g_ip
	fi
	
	if [ "$nm" -eq "0" ]; then
		$send2log "Adding rules in $chain for $mac & $ip" 0
		addIP "$cmd" "$chain" "$ip"
	else
		$send2log "!!! Incorrect number of rules for $ip in $chain -> $nm... removing duplicates" 99
		clearIPs "$cmd" "$chain" "$ip"
		addIP "$cmd" "$chain" "$ip"
	fi

}
checkIPChain()
{
	$send2log "checkIPChain:  $1  $2  $3" 0
	local cmd="$1"
	local chain="$2"
	local base="$3"
	local rule="${base}Entry"
	$send2log "checkIPChain check $cmd for $chain" 0

    local oldRuleinChain=$(eval $cmd $_tMangleOption -nL "$chain" | grep -ic "\b$base\b")
    local i=1
	$send2log ">>> oldRuleinChain-->$oldRuleinChain" 0
    while [ "$i" -le "$oldRuleinChain" ]; do
        local dup_num=$(eval $cmd $_tMangleOption -nL "$chain" --line-numbers | grep -m 1 -i "\b$base\b" | cut -d' ' -f1)
        eval $cmd $_tMangleOption -D "$chain" $dup_num
		$send2log ">>> $cmd $_tMangleOption -D "$chain" $dup_num" 0
        i=$(($i+1))
    done
    
    local foundRuleinChain=$(eval $cmd $_tMangleOption -nL "$chain" | grep -ic "\b$rule\b")
    if [ "$foundRuleinChain" -eq "1" ]; then
        $send2log ">>> Rule $rule exists in chain $chain ==> $foundRuleinChain" 0
    elif [ "$foundRuleinChain" -eq "0" ]; then
        $send2log "Created rule $rule in chain $chain ==> $foundRuleinChain" 2
        eval $cmd $_tMangleOption -I "$chain" -j "$rule"
    else
        $send2log "!!! Found $foundRuleinChain instances of $rule in chain $chain... deleting them individually rather than flushing!" 99
        local i=1
        while [  "$i" -le "$foundRuleinChain" ]; do
            local dup_num=$($cmd -nL "$chain" --line-numbers | grep -m 1 -i "\b$rule\b" | cut -d' ' -f1)
            eval $cmd $_tMangleOption -D "$chain" $dup_num
            i=$(($i+1))
        done
        eval $cmd $_tMangleOption -I "$chain" -j "$rule"
    fi
}
getMACIPList(){
	local iplist=$1
	$send2log "getMACIPList:  $1" 0

	#local list="$(eval "$iplist")"
	local list="$1"
	$send2log "list: $list" -1

	local result
	IFS=$'\n'
	for line in $list
	do
		local ip=$(echo "$line" | cut -d' ' -f1)
		local tip=${ip//\./\\.}
		local mac=$(echo "$line" | cut -d' ' -f2)
		local append
		
		if [ "$mac" == "00:00:00:00:00:00" ] || [ "$mac" == "failed" ] || [ "$mac" == "incomplete" ] ; then
			append=0
		elif [ -n "$(echo $_bridgeMAC | grep -i "$mac")" ] ; then
			append=0
			#$send2log "_bridgeMAC: $append" 1
		else
			append=1
			#$send2log "append: $append" 1
		fi

		local me=$(echo "$result" | grep $mac )
		if [ -z "$me" ] || [ "$append" -eq "0" ] ; then
			result="$result
$mac $ip"
		else
			result=$(echo "$result" | sed -e "s~$mac ~$mac $ip,~Ig")
		fi
		$send2log "mac: $mac / ip: $ip" 0
	done
	unset IFS
	echo "$result"
}
save2File(){ #old... likely unused but left in for legacy
	$send2log "save2File:  $1  $2  $3" -1
	local s_path=${2//\/\//\/}
	if [ -z "$3" ] ;  then
		echo "$1" > "$s_path" #replace the file if param #3 is null
		$send2log "save2File --> data saved to $s_path " 0
	else
		echo "$1" >> "$s_path" #otherwise append to the file
		$send2log "save2File --> data appended to $s_path " 0
	fi
	[ "$_enable_ftp" -eq 1 ] && send2FTP "$s_path"
}
save2File_0(){ #no FTP
	$send2log "save2File0: $2  $3" 0
	local s_path=${2//\/\//\/}
	if [ -z "$3" ] ;  then
		echo "$1" > "$s_path" #replace the file if param #3 is null
		$send2log "save2File --> data saved to $s_path2 " 0
	else
		echo "$1" >> "$s_path" #otherwise append to the file
		$send2log "save2File --> data appended to $s_path " 0
	fi
}
save2File_1(){ # save & FTP
	$send2log "save2File1:   $2  $3" 0
	local s_path=${2//\/\//\/}
	if [ -z "$3" ] ;  then
		echo "$1" > "$s_path" #replace the file if param #3 is null
		$send2log "save2File --> data saved to $s_path " 0
	else
		echo "$1" >> "$s_path" #otherwise append to the file
		$send2log "save2File --> data appended to $s_path " 0
	fi
	send2FTP "$s_path"
}
send2FTP(){
	$send2log "send2FTP" 0
	local fname=$(echo "$1" | sed -e "s~${d_baseDir}/$_webDir~~Ig" | sed -e "s~$d_baseDir~~Ig" | sed -e "s~$_wwwPath~~Ig" | sed -e "s~$_dataDir~$_wwwData~Ig")
	local ftp_path="$_ftp_dir/$fname"
	ftp_path=${ftp_path//\/\//\/}
	ftpput -u "$_ftp_user" -p "$_ftp_pswd" "$_ftp_site" "$ftp_path" "$1"
	$send2log "send2FTP --> $1 sent to FTP site ($ftp_path)" 0
}

digitAdd()
{
	local n1=$1
	local n2=$2
	local l1=${#n1}
	local l2=${#n2}
	[ -z "$n1" ] && n1=0
	[ -z "$n2" ] && n2=0
	if [ "$l1" -lt "10" ] && [ "$l2" -lt "10" ] ; then
		total=$(($n1+$n2))
		echo $total
		return
	fi
	local carry=0
	local total=''
	while [ "$l1" -gt "0" ] || [ "$l2" -gt "0" ]; do
		d1=0
		d2=0
		l1=$(($l1-1))
		l2=$(($l2-1))
		[ "$l1" -ge "0" ] && d1=${n1:$l1:1}
		[ "$l2" -ge "0" ] && d2=${n2:$l2:1}
		s=$(($d1+$d2+$carry))
		sum=$(($s%10))
		carry=$(($s/10))
		total="$sum$total"
	done
	[ "$carry" -eq "1" ] && total="$carry$total"
	[ -z "$total" ] && total=0
	echo $total
	$send2log "digitAdd: $1 + $2 = $total" -1
}
digitSub()
{
	local n1=$(echo "$1" | sed 's/-*//')
	local n2=$(echo "$2" | sed 's/-*//')
	[ -z "$n1" ] && n1=0
	[ -z "$n2" ] && n2=0
	if [ "$n1" == "$n2" ] ; then
		echo 0
		return
	fi
	local l1=${#n1}
	local l2=${#n2}
	if [ "$l1" -lt "10" ] && [ "$l2" -lt "10" ] ; then
		echo $(($n1-$n2))
		return
	fi
	local b=0
	local total=''
	local d1=0
	local d2=0
	local d=0
	while [ "$l1" -gt "0" ] || [ "$l2" -gt "0" ]; do
		d1=0
		d2=0
		l1=$(($l1-1))
		l2=$(($l2-1))
		[ "$l1" -ge "0" ] && d1=${n1:$l1:1}
		[ "$l2" -ge "0" ] && d2=${n2:$l2:1}
		[ "$d2" == "-" ] && d2=0
		d1=$(($d1-$b))
		b=0
		[ $d2 -gt $d1 ] && b="1"
		d=$(($d1+$b*10-$d2))
		total="$d$total"
	done
	[ "$b" -eq "1" ] && total="-$total"
	echo $(echo "$total" | sed 's/0*//')
	$send2log "digitSub: $1 - $2 = $total" -1
}