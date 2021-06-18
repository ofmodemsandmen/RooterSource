#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
#  get a local copy of the JS & CSS files hosted at usage-monitoring.com
#
##########################################################################

d_baseDir=$(cd "$(dirname "$0")" && pwd)
delay=$1
[ -z "$delay" ] && delay=5

source "$d_baseDir/config.file"
source "${d_baseDir}/includes/versions.sh"
source "$d_baseDir/includes/util$_version.sh"
source "${d_baseDir}/includes/defaults.sh"
source "${d_baseDir}/strings/$_lang/strings.sh"

source "$d_baseDir/includes/getLocalCopies.sh"

clear
echo -E "$_s_title"
echo "
******************************************************************

This script will get a local copy of the JS & CSS files hosted
at usage-monitoring.com

******************************************************************
"

[ ! -f "${d_baseDir}/config.file" ] && [ ! -f "${d_baseDir}/default_config.file" ] && echo '*** Cannot find either config.file or default config.file... 
	*** Please check your installation! ***
	*** Exiting the script. ***' && exit 0
    
_configFile="${d_baseDir}/config.file"
[ ! -f "$_configFile" ] && _configFile="${d_baseDir}/default_config.file"
source "$_configFile"
loadconfig()

sleep $delay

if [ "${_logDir:0:1}" == "/" ] ; then
   _logfilename="${_logDir}/glc.log"
else
   _logfilename="${d_baseDir}/${_logDir}/glc.log"
fi 
_logfilename=${_logfilename//\/\//\/}

echo "Log info will be written to $_logfilename"
[ ! -f "$_logfilename" ] && touch "$_logfilename"
$send2log  "Log file:  \`$_logfilename\`" 1
$send2log "Loading baseline settings from \`$_configFile\`." 2

sleep $delay


getLocalCopies

echo "

Done!  Local copies of the files have been updated.

"