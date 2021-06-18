#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
###########################################################################

# this script purges all log and backup files older than 30 days (by default)
# either change the value of days below or call the script with a parameter
# e.g., `/opt/YAMon3/purge.sh 14` to delete all logs & backups create more 
# that 2 weeks ago.

# adding this as cron job is left as an exercise :-)

days=$1
[ -z "$days" ] && days=30

d_baseDir=$(cd "$(dirname "$0")" && pwd)
lfname="${d_baseDir}/logs/purge.log"
[ ! -f "$lfname" ] && touch "$lfname" 

ds=$(date +"%Y-%m-%d %H:%M:%S")
echo "$ds - purging logs & backups for past $days days" >> "$lfname"
find "${d_baseDir}/logs/" -name *.log -mtime +$days -exec rm -f {} \;
find "${d_baseDir}/daily-bu2/" -name *.tar -mtime +$days -exec rm -f {} \;