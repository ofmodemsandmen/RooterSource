#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
#  re-aggregate monthly data from the hourly file
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
source "${d_baseDir}/includes/hourly2monthly.sh"

d_max_digits=$(check4Overflow)

_cYear=$(date +%Y)
_cDay=$(date +%d)
_cMonth=$(date +%m)
_ds="$_cYear-$_cMonth-$_cDay"

clear
echo -E "$_s_title"
echo -e "${los}${_nl}This script will fill missing data gaps in your monthly usage file.${los}${_nl}"

sleep $delay

if [ "${_logDir:0:1}" == "/" ] ; then
   _logfilename="${_logDir}/h2m.log"
else
   _logfilename="${d_baseDir}/${_logDir}/h2m.log"
fi 
_logfilename=${_logfilename//\/\//\/}
_configFile="${d_baseDir}/config.file"
_alertfilename="$_wwwPath${_wwwJS}alerts.js"

echo "_logfilename-->$_logfilename"
echo "_configFile-->$_configFile"
[ ! -f "$_logfilename" ] && touch "$_logfilename"
$send2log  "Log file:  \`$_logfilename\`." 1
$send2log "Loading baseline settings from \`$_configFile\`." 1

sleep $delay

echo -e "${_nl}In the prompts below, the recommended value is denoted with${_nl}an asterisk (*).  To accept this default, simply hit enter;${_nl}otherwise type your preferred value (and then hit enter).${_nl}"

zo_r=^[01]$


da=$(date +%d)
mo=$(date +%m)
mo=${mo#0}
[ ${da#0} -lt $_ispBillingDay ] && mo=$(($mo - 1))
rYear=$(date +%Y)

prompt 'mo' "Enter the month number of the reporting interval for which your are missing data:" '(Jan-->1, Feb-->2... Dec-->12)' "$mo" ^[1-9]$\|^[1][0-2]$ 'h2m'
prompt 'rYear' "Enter the year:" '' "$rYear" ^20[1-9][0-9]$ 'h2m'
prompt 'just' "Do you want to update the entire month or just one specific day?" 'Select 0 for the entire month or input the day number' "0" ^[0-9]$\|^[12][0-9]$\|^[3][01]$ 'h2m'
ap=0
[ "$just" -eq "0" ] && prompt 'ap' "Do you want to store the results in a new file or append them to the existing monthly data file?" 'Options: 0->New file(*) -or- 1->Append to existing' "0" $zo_r 'h2m'

rDay=$(printf %02d $_ispBillingDay)
rMonth=$(printf %02d $mo)

if [ "${_dataDir:0:1}" == "/" ] ; then
	_dataPath=$_dataDir
else
	_dataPath="${d_baseDir}/$_dataDir"
fi
case $_organizeData in
	(*"0"*)
		savePath="$_dataPath"
	;;
	(*"1"*)
		savePath="$_dataPath/$rYear/"
	;;
	(*"2"*)
		savePath="$_dataPath/$rYear/$rMonth/"
	;;
esac
savePath=${savePath//\/\//\/}

[ ! -d "$savePath" ] && mkdir -p "$savePath"

if [ "$ap" -eq "0" ] ; then
	fn=$(echo "$_usageFileName" | cut -d'.' -f1)
	ts=$( date +"-%H%M")
	_usageFileName="${fn}$ts.js"
fi

if [ -z "$(which sort)" ] || [ -z "$(which uniq)" ] ; then
	tallyHourlyData="tallyHourlyData_0"
else
	tallyHourlyData="tallyHourlyData_1"
fi

_macUsageDB="$savePath$rYear-$rMonth-$_usageFileName"
ds=$(date +"%Y-%m-%d %H:%M:%S")
if [ ! -f "$_macUsageDB" ] ; then
	touch $_macUsageDB
	echo "var monthly_created=\"$ds\"
var monthly_updated=\"$ds\"
var monthlyDataCap=\"$_monthlyDataCap\"" > $_macUsageDB
fi

showProgress=1

# Set nice level to 10 of current PID (low priority)
if [ -z "$(which renice)" ] ; then 
	$send2log ">>> Setting renice does not exist in this firmware" 1
else
	$send2log ">>> Setting renice level to 10 on PID: $$" 1
	renice 10 $$
fi

if [ "$just" -eq "0" ] ; then #entire month
	mm=${rMonth#0}
	case $mm in
		(*2*) #February
			if [ $(($rYear % 4)) -eq 0 ] ;  then  #leap year... this calculation will have to be corrected for year 2200
				dim=29
			else
				dim=28
			fi
		;;
		(*1|3|5|7|8|10|12*) #months with 31 days
			dim=31
		;;
		(*4|6|9|11*) #months with 30 days
			dim=30
		;;
	esac
	echo -e "${_nl}${los}${_nl}Processing all $dim data files for billing interval starting: $rYear-$rMonth-$rDay"

	i=$_ispBillingDay
	while [  "$i" -le "$dim" ] ; do
		updateHourly2Monthly "$rYear" "${rMonth#0}" "$(printf %02d $i)"
		i=$(($i+1))
	done
	$send2log ">>> Finished to end of month" 1

	if [ "$rMonth" -eq "12" ]; then
		rMonth='01'
		rYear=$(($rYear+1))
	else
		nm=$((${rMonth#0}+1))
		rMonth=$(printf %02d $nm)
	fi

	i=1
	while [  $i -lt "$_ispBillingDay" ] ; do
		d=$(printf %02d $i)
		updateHourly2Monthly "$rYear" "${rMonth#0}" "$d"
		i=$(($i+1))
	done
	$send2log ">>> Finished start to end of next interval" 1

	ds=$(date +"%Y-%m-%d %H:%M:%S")
	calcMonthlyTotal "$_macUsageDB"
else #just particular day(s) of the month
	echo -e "${_nl}${los}${_nl}Processing selected data files for billing interval starting: $rYear-$rMonth-$rDay"
	_qn=0 #reset prompt #
	while [ 1 ] ; do
		jd=$(printf %02d $just)
		jm=$mo
		jy=$rYear
		if [ "$just" -lt "$_ispBillingDay" ] ; then
			if [ "$mo" -eq "12" ]; then
				jm='01'
				jy=$(($rYear+1))
			else
				jm=$(($mo+1))
				jm=$(printf %02d $jm)
			fi
		fi
		[ "$_qn" -eq "0" ] && echo -e "${_nl}>>> Starting with: $jy-$jm-$jd"
		[ "$_qn" -gt "0" ] && echo -e "${_nl}>>> Then: $jy-$jm-$jd"
		updateHourly2Monthly "$jy" "$jm" "$jd"
		just=0
		prompt 'just' "Do you want to update another day?" 'Select 0 for `no` or input the day number' "0" ^[0-9]$\|^[12][0-9]$\|^[3][01]$ 'h2m'
		[ "$just" -eq "0" ] && break
	done 
	calcMonthlyTotal "$_macUsageDB"
fi
echo -e "${_nl}${_nl}=== Done updateHourly2Monthly ===${_nl}Note: the re-calculated values have been saved to:${_nlsp}$_macUsageDB"

[ "$ap" -eq "0" ] && echo -e "${_nl}These updated values will not appear in your reports until you either ${_nl}  a) rename this file, or${_nl}  b) copy and paste the values from this file into your active monthly usage file.${_nl}${_nl}NB - you do *not* have to stop the main script to copy the data from${_nl}the new file into your active monthly data file.${_nl}${_nl}"
