#!/bin/sh 

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
###########################################################################

_sendAlerts=1  #Values: 0--> No || 1-->via usage-monitoring.com || 2-->using MSMTP if you have it in your firmware
_sendAlertTo=''
_debugging=0


d_baseDir=`dirname $0`
_configFile="$d_baseDir/config.file"
source "$_configFile"
source "${d_baseDir}/includes/versions.sh"
source "${d_baseDir}/includes/defaults.sh"
loadconfig

send2log()
{
	local ts=$(date +"%H:%M:%S")
	#echo "$ts	$1" >> "$lfname"
    [ "$_sendAlerts" -gt "0" ] && [ -z "$2" ] && sendAlert "$1" $ts
}

sendAlert()
{
	local subj="$1"
	local ts="$2"

	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	msg="Running restart.sh @ $ts"

	if [ "$_sendAlerts" -eq "1" ] ; then
		subj=$(echo "$subj" | tr "'" '`')
		msg=$(echo "$msg" | tr "'" '`')
		local url="http://usage-monitoring.com/current/sendmail.php"
		
        if [ -x /usr/bin/curl ] ; then
            curl -G -sS "$url" --data-urlencode "t=$_sendAlertTo" --data-urlencode "s=$subj" --data-urlencode "m=$msg"
        else
            wget "$url?t=$_sendAlertTo&s=$subj&m=$msg" -q
		fi

	elif [ "$_sendAlerts" -eq "2" ] ; then
		ECHO=/bin/echo
		$ECHO -e "Subject: $subj\n\n$msg\n\n" | $_path2MSMTP -C $_MSMTP_CONFIG -a gmail $_sendAlertTo
	fi
}

_cDay=$(date +%d)
_cMonth=$(date +%m)
_cYear=$(date +%Y)


lfpath="${d_baseDir}/$_logDir"
[ "${_logDir:0:1}" == "/" ] && lfpath=$_logDir
lfname="${lfpath}watchdog-$_cYear-$_cMonth-$_cDay.log"
[ ! -f "$lfname" ] && touch "$lfname" 

np=$(ps | grep -v "grep" | grep -c "yam")
[ "$np" -eq "0" ] && send2log "Missing process..." && "$d_baseDir/restart.sh" 0 && exit
[ ! -d "$_lockDir" ] && send2log "Missing directory... $_lockDir" && "$d_baseDir/restart.sh" 0 && exit
send2log "Watchdog done" false