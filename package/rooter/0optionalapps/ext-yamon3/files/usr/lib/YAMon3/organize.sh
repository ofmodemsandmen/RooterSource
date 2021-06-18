#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
#  This program organizes files in your data directory as per settings in 
#  config.file
#
#  Updated: 
#  - May 23, 2015 - recreated this file
#
##########################################################################
	
d_baseDir=$(cd "$(dirname "$0")" && pwd)
_configFile="${d_baseDir}/config.file"
d_usageFileName="mac_data2.js"
_loglevel=1
_logFileName="monitor-*.log"

send2log(){
	[ "$2" -ge "$_loglevel" ] && echo "$1"
}

organizeByYr(){
 
    send2log "Organizing by year

    >>> Be patient... as it may take several minutes for this process to complete!
    " 2
    
   for f in $datadir
    do
        local fn=$(echo "$f" | cut -d'/' -f5)
        if [ "$fn" == "users.js" ] ; then 
            return 
        fi
        
        local yr=$(echo "$fn" | cut -d'-' -f1)
        local mo=$(echo "$fn" | cut -d'-' -f2)
        local da=$(echo "$fn" | cut -d'-' -f3)
        local rm=${mo#0}
        local ry="$yr"
        if [ "$da" -lt "$_ispBillingDay" ] ; then
            rm=$(($rm-1))
            if [ "$rm" == "0" ] ; then
                rm=12
                ry=$(($ry-1))
            fi
        fi
        local rm=$(printf %02d $rm)
        [ "$_loglevel" -eq "0" ] && send2log "Processing $fn... yr: $yr    mo: $mo    da: $da ($_ispBillingDay) -----> $ry-$rm" 0
        send2log "Processing $fn" 2
        dest="$savePath$ry"
        [ ! -d "$dest" ] && mkdir -p "$dest"
        $(mv -n "$f" "$dest")
    done
}
organizeByYrMo(){
 
    send2log "Organizing by year & month

    >>> Be patient... as it may take several minutes for this process to complete!
    " 2
    
   for f in $datadir
    do
        local fn=$(echo "$f" | cut -d'/' -f5)
        if [ "$fn" == "users.js" ] ; then 
            return 
        fi
        
        local yr=$(echo "$fn" | cut -d'-' -f1)
        local mo=$(echo "$fn" | cut -d'-' -f2)
        local da=$(echo "$fn" | cut -d'-' -f3)
        local rm=${mo#0}
        local ry="$yr"
        if [ "$da" -lt "$_ispBillingDay" ] ; then
            rm=$(($rm-1))
            if [ "$rm" == "0" ] ; then
                rm=12
                ry=$(($ry-1))
            fi
        fi
        local rm=$(printf %02d $rm)
        [ "$_loglevel" -eq "0" ] && send2log "Processing $fn... yr: $yr    mo: $mo    da: $da ($_ispBillingDay) -----> $ry-$rm" 0
        send2log "Processing $fn" 2
        dest="$savePath$ry/$rm"
        [ ! -d "$dest" ] && mkdir -p "$dest"
        $(mv -n "$f" "$dest")
    done
}

send2log "
=== Organize data === 
" 2
if [ ! -f "$_configFile" ] ; then
	send2log "*** Cannot find  \`config.file\` in the following location:
>>>	$_configFile
If you are using a different default directory (other than the one specified above), 
you must edit lines 16-17 in this file to point to your file location.
Otherwise, check spelling and permissions." 0
	exit 0
fi

send2log "Reading config.file --> $_configFile" 0
while read row
do
	eval $row
done < $_configFile

#_dataDir="data3/"
_buDir="data-bu/"
savePath="${d_baseDir}/$_dataDir"
buPath="${d_baseDir}/$_buDir"

if [ "$_organizeData" -ne "0" ] ; then
    send2log "Backing up $savePath to $buPath " 2
    $(cp -a "$savePath" "$buPath")
fi
local datadir="${d_baseDir}/$_dataDir*.js"
send2log "Processing files: $datadir" 2

case $_organizeData in
	(*"0"*)
		send2log "_organizeData --> $_organizeData... nothing to do" 2
	;;
	(*"1"*)
        organizeByYr
	;;
	(*"2"*)
        organizeByYrMo 
	;;
esac

send2log "
*******************
****    Done    ***
*******************" 2
