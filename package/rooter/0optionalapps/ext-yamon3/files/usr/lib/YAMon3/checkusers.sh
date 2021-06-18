#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
#  removes bad entries from the users.js file
#  commandline parameters: /opt/YAMon3/checkusers.sh <startup_delay> <alternate_path_to_datafile>
#    -> startup_delay: delay in seconds for the splash screen and between various sections of output;
#       by default, 5 seconds
#    -> alternate_path_to_datafile: if null, the location of users.js as set in config.file;
#       otherwise, a relative path to the file (really just for my testing purposes)
#    e.g., /opt/YAMon3/checkusers.sh 0 test/test.file
#
# 2019-07-23 v1.0.0 - initial version
# 2019-07-26 v1.0.1 - added code to remove incompletes as well
#
##########################################################################

indentList(){
	local tl="$1"
	echo "$tl" | sed -e "s~^\s\{0,\}~      ~Ig" 
}
getNum(){
	[ -z "$1" ] && echo 0 || echo "$1" | wc -l
}
d_baseDir=$(cd "$(dirname "$0")" && pwd)
delay=$1
[ -z "$delay" ] && delay=5

source "$d_baseDir/config.file"
source "${d_baseDir}/includes/versions.sh"
source "$d_baseDir/includes/util$_version.sh"
source "${d_baseDir}/includes/defaults.sh"
source "${d_baseDir}/strings/$_lang/strings.sh"

echo -e "${los}"
echo -E "$_s_title" 
echo -e "${los}"

echo -e "This script will check the integrity of your users.js file.
If necessary, any bad entries will be fixed or removed 
(but the contents of the current file will be backed-up to a separate file)
YAMon will be shut down before proceeding... (and restarted upon completion)"

if [ -z "$(which sort)" ] || [ -z "$(which uniq)" ] ; then
	echo -e "${_nl}${los}${_err}${_nls}Your firmware version does not support the\`sort\` ${_nls}or the \`uniq\` function.${_nls}Sorry but you will have to check your file by hand.${_nls}${_nls}   Exiting...${los}"
	exit 0
fi

${d_baseDir}/shutdown.sh 0

sleep $delay

if [ "${_dataDir:0:1}" == "/" ] ; then
	_dataPath=$_dataDir
else
	_dataPath="${d_baseDir}/$_dataDir"
fi

echo -e "${_nl}Paths:" 
echo -e "    _dataPath --> \`$_dataPath\`" 
if [ ! -d "$_dataPath" ] ; then
	echo -e ">>> Cannot find the data path?!?  Check your settings in config.file and try again." 
	exit 0
fi
[ ! -z "$2" ] && _usersFileName="$2"
_usersFile="$_dataPath$_usersFileName"
echo -e "    _usersFile --> \`$_usersFile\`" 
if [ ! -f "$_usersFile" ] ; then
	echo -e ">>> Cannot find your users.js file?!?  Check your settings in config.file and try again." 
	exit 0
fi
ts=$( date +"_%m%d-%H%M")
ufn=${_usersFileName/.js/}
buFile="$_dataPath$ufn$ts.js"
#cp $_usersFile $buFile
echo -e "    backed up to --> \`$buFile\`" 

sleep $delay

echo -e "${_nl}New Device Defaults (if device info cannot be gathered from $_dnsmasq_conf or $_dnsmasq_leases):" 
echo -e "    Owner/Group --> \`$_defaultOwner\`" 
echo -e "    Name --> \`$_defaultDeviceName\`-## (where ## will increment for each new device)" 
echo -e "    Separator --> \`$_do_separator\` 
	e.g., the default character to split the group and name values
	--> if set to \`-\`, Al-Phone would get split to Owner: Al & Name: Phone)" 

echo -e "${_nl}Other applicable settings from your \`config.file\`:" 
echo -e "    Include IPv6 addresses --> \`$_includeIPv6\`" 
echo -e "    Multiple IPs/MAC --> \`$_allowMultipleIPsperMAC\`" 
[ "$_allowMultipleIPsperMAC" -eq 1 ] && echo -e "    for MAC --> \`$_multipleIPMAC\`" 

echo -e "${_nl}${los}${_nl}"

sleep $delay

contents=$(cat "$_usersFile")
created=$(echo "$contents" | grep "users_created")
users=$(echo "$contents" | grep "^ud_a")
created_date=$(echo "$created" | cut -d= -f2 | cut -d\" -f2)
modified=$(date -r "$_usersFile" "+%Y-%m-%d %H:%M:%S")

echo -e "$created${_nl}${_nl}$(echo "$users" | sort)" > "$buFile"

echo -e "Creation date --> \`$created_date\`" 
echo -e "Last modified --> \`$modified\`" 

num_entries=$(echo "$users" | grep -c "^ud_a")
null_ip4=$(echo "$users" | grep -c "\"ip\":\"\s\{0,\}\"")
null_ip6=$(echo "$users" | grep -c "\"ip6\":\"\s\{0,\}\"")
null_both=$(echo "$users" | grep "\"ip\":\"\s\{0,\}\"" | grep -c "\"ip6\":\"\s\{0,\}\"")
echo -e "# of entries --> \`$num_entries\`"

echo -e "${_nl}IP Addresses:${_nl}------------" 
echo -e "# without IPv4 address --> \`$null_ip4\`" 
[ "$_includeIPv6" -eq '1' ] && echo -e "# without IPv6 address --> \`$null_ip6\`" 
echo -e "# with neither IP address --> \`$null_both\`" 

IFS=$'\n'
yn_y="Options: \`0\` / \`n\` -> No -or- \`1\` / \`y\` -> Yes (*)"
zo_r=^[01nNyY]$

ipList=$(echo "$users" | grep -o "\"ip\":\"[^\"]\{1,\}\"" | grep -v "(dup)" | sort -k1 | uniq -c )

#duplicated active IP addresses - i.e., without (dup) suffix
list=$(echo "$ipList" | grep -v "^\s\{0,\}1\s")
num=$(getNum "$list")
if [ "$num" -gt 0 ] ; then
	prompt 't_prompt' "You have $num_dup_ip duplicated IP addresses.${_nl}$(indentList "$list")${_nlsp}Do you want to mark these entries as duplicates? " "$yn_y" '1' $zo_r
	if [ "$t_prompt" == "1" ] ; then
		count=0
		x=0
		echo -e "${_nl}    Making the following changes:"
		for line in $list
		do	
			x=$(($x + 1))
			n=$(echo "$line" | tr -s ' ' | cut -d' ' -f2)
			bv=$(echo "$line" | tr -s ' ' | cut -d' ' -f3)
			fix=${bv%\"}" (dup)\""
			users=$(echo "$users" | sed -e "s~$bv~$fix~Ig")
			echo -e "	$x. $bv-->$fix ($n entries)"
			count=$(($count + $n))
		done
		echo -e "    --> A total of $count entries were updated"
	fi
	t_prompt=''
fi

#odd IP addresses - e.g., 192.168.1.056 instead of 192.168.1.56
list=$(echo "$users" | grep -o "\"ip\":\"[^\"]\{1,\}\.0[1-9][^\"]\{1,\}\"")
num=$(getNum "$list")
if [ "$num" -gt 0 ] ; then
	prompt 't_prompt' "You have $num entries with oddly formed IP addresses.${_nl}$(indentList "$list")${_nlsp}Do you want to fix these entries? " "$yn_y" '1' $zo_r
	if [ "$t_prompt" == "1" ] ; then
		x=0
		echo -e "${_nl}    Making the following changes:"
		for line in $list
		do
			x=$(($x + 1))
			bv=$(echo "$line" | grep -o "\.0[1-9][^\"]")
			fix=${bv/\.0/\.}
			fixed=$(echo "$line" | sed -e "s~$bv~$fix~Ig")
			users=$(echo "$users" | sed -e "s~$bv~$fix~Ig")
			echo -e "	$x. $line-->$bv-->$fix-->$fixed"
		done
		echo -e "    --> A total of $x entries were updated"
	fi
	t_prompt=''
fi

echo -e "${_nl}MAC Addresses:${_nl}-------------"
mac_list=$(echo "$users" | grep -o "\"mac\":\"[^\"]\{1,\}\"")
num_mac=$(echo "$mac_list" | wc -l)
[ -z "$mac_list" ] && num_mac=0 
echo -e "# of macs --> \`$num_mac\`" 

lower_case=$(echo "$mac_list" | grep -o "\"mac\":\"\(\([a-f0-9]\)\{2\}[:-]\)\{5\}\([a-f0-9]\)\{2\}\"")
num_lc=$(echo "$lower_case" | wc -l)
[ -z "$lower_case" ] && num_lc=0
echo -e "# of lower case --> \`$num_lc\` (recommended)" 

others=$(echo "$mac_list" | grep -v "\"mac\":\"\(\([a-f0-9]\)\{2\}[:-]\)\{5\}\([a-f0-9]\)\{2\}\"")
num_o=$(echo "$others" | wc -l)
[ -z "$others" ] && num_o=0
echo -e "# of others --> \`$num_o\`" 

#upper case MAC addresses
list=$(echo "$others" | grep -o "\"mac\":\"\(\([A-F0-9]\)\{2\}[:-]\)\{5\}\([A-F0-9]\)\{2\}\"")
num=$(getNum "$list")
if [ "$num" -gt 0 ] ; then
	prompt 't_prompt' "You have $num entries with upper case MAC addresses.${_nl}$(indentList "$list")${_nlsp}Do you want to change these to lower case? " "$yn_y" '1' $zo_r
	if [ "$t_prompt" == "1" ] ; then
		for line in $list
		do
			bv=$(echo "$line" | cut -d'"' -f4)
			fix=$(echo "$bv" | tr "[A-Z]" "[a-z]")
			others=$(echo "$others" | sed -e "s~$line~~Ig")
			users=$(echo "$users" | sed -e "s~$bv~$fix~Ig")
			echo -e "	$line-->$bv-->$fix"
		done
	fi
	t_prompt=''
fi

#mixed case MAC addresses
list=$(echo "$others" | grep -v "\"mac\":\"\(\([0-9]\)\{2\}[:-]\)\{5\}\([0-9]\)\{2\}\"" | grep -v "\"mac\":\"\(\([a-f0-9]\)\{2\}[:-]\)\{5\}\([a-f0-9]\)\{2\}\"" | grep "\"mac\":\"\(\([a-fA-F0-9]\)\{2\}[:-]\)\{5\}\([a-fA-F0-9]\)\{2\}\"")
num=$(getNum "$list")
if [ "$num" -gt 0 ] ; then
	prompt 't_prompt' "You have $num entries with mixed case MAC addresses.${_nl}$(indentList "$list")${_nlsp}Do you want to change these to lower case? " "$yn_y" '1' $zo_r
	if [ "$t_prompt" == "1" ] ; then
		for line in $list
		do
			bv=$(echo "$line" | cut -d'"' -f4)
			fix=$(echo "$bv" | tr "[A-Z]" "[a-z]")
			others=$(echo "$others" | sed -e "s~$line~~Ig")
			users=$(echo "$users" | sed -e "s~$bv~$fix~Ig")
			echo -e "	$line-->$bv-->$fix"
		done
	fi
	t_prompt=''
fi
others=$(echo "$others" | grep -v "^$") 

#with bad MAC addresses
list=$(echo "$others" | grep -v "un:kn:ow:n0:0m:ac" | grep -v "in:co:mp:le:te-" | grep -v "\"mac\":\"\(\([a-f0-9]\)\{2\}[:-]\)\{5\}\([a-f0-9]\)\{2\}\"" | grep -v "\"mac\":\"\(\([A-F0-9]\)\{2\}[:-]\)\{5\}\([A-F0-9]\)\{2\}\"" | sort -u)
num=$(getNum "$list")
if [ "$num" -gt 0 ] ; then
	prompt 't_prompt' "You have $num entries with bad MAC addresses.${_nl}$(indentList "$list")${_nlsp}Do you want to delete them? " "$yn_y" '1' $zo_r
	if [ "$t_prompt" == "1" ] ; then
		echo -e "    The following bad entries have been removed from users.js:"
		for line in $list
		do
			bv=$(echo "$line" | cut -d'"' -f4)
			others=$(echo "$others" | grep -iv "$bv")
			users=$(echo "$users" | grep -iv "$bv")
			echo -e "	$line-->$bv"
		done
		echo -e "    Any traffic associated with these entries is still in your hourly & monthly usage files.${_nlsp}That traffic will be rolled into the unknown mac bucket in the reports."
	fi
	t_prompt=''
fi

#with duplicated MAC addresses
list=$(echo "$users" | grep -o "\"mac\":\"[^\"]\{1,\}\"" | sort -k1 | uniq -c | grep -v "^\s\{0,\}1\s" | tr -s ' ')
num=$(getNum "$list")
if [ "$num" -gt 0 ] ; then
	prompt 't_prompt' "You have $num entries with duplicated MAC addresses.${_nl}$(indentList "$list")${_nlsp}Do you want to delete the duplicated entries? " "$yn_y" '1' $zo_r
	if [ "$t_prompt" == "1" ] ; then
		echo -e "    The following duplicated entries have been removed from users.js:"
		for line in $list
		do
			bv=$(echo "$line" | cut -d'"' -f4)
			mm=$(echo "$users" | grep -m1 "$bv")
			users=$(echo "$users" | grep -iv "$bv")
			users=$(echo -e "$users${_nl}$mm")
		done
	fi
fi

#incomplete MAC addresses
list=$(echo "$others" | grep -v "un:kn:ow:n0:0m:ac" )
num=$(getNum "$list")
if [ "$num" -gt 0 ] ; then
	prompt 't_prompt' "You have $num remaining entries with odd MAC addresses.${_nl}$(indentList "$list")${_nlsp}  For info about the \`incomplete\` entries,${_nlsp}  see http://usage-monitoring.com/help/?t=incomplete-mac?${_nlsp}Do you want to delete them? " "$yn_y" '1' $zo_r
	if [ "$t_prompt" == "1" ] ; then
		echo -e "    The following entries have been removed from users.js:"
		for line in $list
		do
			bv=$(echo "$line" | cut -d'"' -f4)
			users=$(echo "$users" | grep -iv "$bv")
			echo -e "	$bv"
		done
	fi
fi
echo -e "$created

$(echo "$users" | sort)" > "$_usersFile"

echo -e "${_nl}${los}${_nl}Your users.js file has been updated.  The previous version of the 
file has been backed up to \`$buFile\`.
NB - the entries have been shorted alphabetically by MAC address 
(primarily to aid with testing).
Entries associated with \`bad\` MAC addresses have not been deleted from your 
hourly & monthly data files.  It will take a week or so but I will update the 
reports to tally the traffic for the bad address into the unknown device bucket 
(so you may still see the entries in reports for awhile yet)
The bad entries (specifically \`used\` and \`ref\`) should not reappear in your 
users.js once you've updated to v3.4.8.${los}"

sleep $delay

t_prompt=''
prompt 't_prompt' 'Do you want to restart YAMon?' "$yn_y" '1' $zo_r
if [ "$t_prompt" == "1" ] ; then
	${d_baseDir}/restart.sh 0
else
	echo -e "You will have to restart YAMon manually."
fi