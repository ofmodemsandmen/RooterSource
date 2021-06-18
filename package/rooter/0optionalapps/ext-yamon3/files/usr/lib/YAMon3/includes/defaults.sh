##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# default parameters - these values may be updated in readConfig()
#
# History
# 3.2.2 - moved _version and _file_version to versions.sh
# 3.3.1 - changed YAMON_IP4, YAMON_IP6, d_configWWW
#       - added d_use_nf_conntrack
#       - removed unused d_lan_iface_only, d_enable_db
# 3.4.0 - uprev'd for new release; some values tweaked & some house keeping
# 3.4.7 - updates for crippled ipv6
# 3.4.8 - added d_guest_iface
##########################################################################

_has_nvram=0
_has_uci=0
_canClear=$(which clear)

[ -n "$YAMON" ] && d_baseDir="${YAMON%/}"
[ -z "$d_baseDir" ] && d_baseDir=$(cd "$(dirname "$0")" && pwd)
[ -n "$(which nvram)" ] && _has_nvram=1
[ -n "$(which uci)" ] && _has_uci=1

_lockDir="/tmp/YAMon$_file_version-running"

YAMON_IP4='YAMON34v4'
YAMON_IP6='YAMON34v6'
_PRIVATE_IP4_BLOCKS='172.16.0.0/12,10.0.0.0/8,192.168.0.0/16'
_LOCAL_IP4='255.255.255.255,224.0.0.1,127.0.0.1'
_PRIVATE_IP6_BLOCKS='fc00::/7,ff02::/7'
[ -z "$_local_ip6" ] && _local_ip6='fe80:'

#global defaults
d_firmware=0
d_updatefreq=30
d_publishInterval=4
_lang='en'
d_path2strings="$d_baseDir/strings/$_lang/"
d_webDir="www/"
d_webIndex="yamon$_file_version.html"
d_dataDir="data/"
d_logDir="logs/"
d_wwwPath="/tmp/www/"
d_wwwURL="/user"
d_wwwJS="js/"
d_wwwCSS="css/"
d_wwwImages='images/'
d_wwwData="data"
d_usersFileName="users.js"
d_hourlyFileName="hourly_data.js"
d_usageFileName="mac_data.js"
d_configWWW="config$_file_version.js"
d_symlink2data=1
d_enableLogging=1
d_log2file=1
d_loglevel=0
d_scrlevel=0
d_ispBillingDay=5
d_doDailyBU=1
d_tarBUs=0
d_doLiveUpdates=1
d_doCurrConnections=1
d_liveFileName="live_data3.js"
d_dailyBUPath="daily-bu/"
d_unlimited_usage=0
d_unlimited_start="02:00"
d_unlimited_end="08:00"
d_settings_pswd=''
d_dnsmasq_conf="/tmp/dnsmasq.conf"
d_dnsmasq_leases="/tmp/dnsmasq.leases"
d_do_separator=""
d_includeBridge=0
d_bridgeMAC='XX:XX:XX:XX:XX:XX'
d_defaultOwner='Unknown'
d_defaultDeviceName='New Device'
d_includeIPv6=0
d_doLocalFiles=0
d_dbkey=''
d_ignoreGateway=0
d_gatewayMAC=''
d_sendAlerts=0
d_organizeData=2
d_allowMultipleIPsperMAC=0
d_multipleIPMAC='XX:XX:XX:XX:XX:XX'
d_includeIPv6=0
d_enable_ftp=0
d_ftp_site=''
d_ftp_user=''
d_ftp_pswd=''
d_ftp_dir=''
d_useTMangle=0
d_logNoMatchingMac=0
d_use_nf_conntrack=1
d_path2MSMTP=/opt/usr/bin/msmtp
d_MSMTP_CONFIG=/opt/scripts/msmtprc
d_includeIncomplete='0'
d_guest_iface=''

_generic_ipv4="0.0.0.0/0"
_generic_ipv6="::/0"
_generic_mac="un:kn:ow:n0:0m:ac"

loadconfig()
{
	local caller=$0

	#if the parameters are missing then set them to the defaults
	local dirty=0
	local mfl=''
	local p_list=$(cat "${d_baseDir}/default_config.file" | grep -o "^_[^=]\{1,\}")

	IFS=$'\n'
	for line in $(echo "$p_list")
	do
		eval nv=\"\$$line\"
		[ -n "$nv" ] && continue
		local dvn="d$line"
		eval dv=\"\$$dvn\"
		[ -z "$dv" ] && continue
		dirty=$(($dirty+1))
		eval $line=\"\$$dvn\"
		mfl="$mfl
	* $line ($dv)"
	done

	[ -z "$(which ftpput)" ] && [ "$_enable_ftp" -eq 1 ] && _enable_ftp=0 && echo -e "${_uhoh}the value of '_enable_ftp' has been changed to 0${_nlsp}because command ftpput was not found?!?${_nls}Please check your config.file${nl}" >&2
	save2File="save2File_"$_enable_ftp

	[ -z "$_path2ip" ] && _path2ip=$(which ip)
	if [ "$_includeIPv6" -eq "1" ] ; then
		$($_path2ip -6 neigh show >> /tmp/ipv6.txt 2>&1)
		if [ $? -ne 0 ] ; then
			_includeIPv6=0
			[ ! -z $(echo $caller | grep "yamon") ] && echo -e "${_uhoh}the value of '_includeIPv6' has been changed to 0 because your${nlsp}installed version of the ip function does not support IPv6 or the neigh parameter.${nls}Please check your config.file and/or your version of busybox.${nlsp}See also http://usage-monitoring.com/help/?t=ipv6-changed${nl}" >&2 
			rm /tmp/ipv6.txt
		fi 
	fi 

	updateUsage="updateUsage_"$_includeIPv6
	doliveUpdates="doliveUpdates_"$_doLiveUpdates

	copyfiles="copyfiles_"$_symlink2data
	checkUnlimited="checkUnlimited_"$_unlimited_usage
	checkIPv6="checkIPv6_"$_includeIPv6

	if [ "$_enableLogging" -eq "0" ] ; then
		send2log="send2log_"$_enableLogging
	else
		send2log="send2log_"$_enableLogging"_"$_log2file
	fi
	if [ "$_sendAlerts" -eq "0" ] ; then
		sendAlert="sendAlert_$_sendAlerts" 
	elif [ -z "$_sendAlertTo" ] ; then
		sendAlert="sendAlert_0" 
		$send2log "_sendAlertTo cannot be null if '_sendAlerts' is not zero" 2
	else
		sendAlert="sendAlert_1"
	fi
	[ "$dirty" -gt 0 ] && echo -e "${_uhoh}$dirty parameter(s) are missing in your config.file!$mfl${_nlsp}The missing entries have been assigned the defaults from \`default_config.file\`.${_nlsp}Run setup.sh again to update your config.file and see \`default_config.file\`${_nlsp}for more info about these parameters.${_nlsp}See also http://usage-monitoring.com/help/?t=missing_parameters ${_nl}"
	
	if [ "$_unlimited_usage" -eq "1" ] ; then
		_ul_start=$(date -d "$_unlimited_start" +%s);
		_ul_end=$(date -d "$_unlimited_end" +%s);
		[ "$_ul_end" -lt "$_ul_start" ] && _ul_start=$((_ul_start - 86400))
	fi

	local ipv6_enable=''
	if [ "$_has_nvram" -eq "1" ] ; then
		ipv6_enable=$(nvram get ipv6_enable)
	fi

	[ "$_firmware" -eq '0' ] && [ "$_includeIPv6" -eq '1' ] && [ -z "$ipv6_enable" ] && _includeIPv6=0 && echo "Setting \`_includeIPv6=0\` because ipv6_enable!=1 in nvram"

	_tMangleOption=''
	[ "$_useTMangle" -eq "1" ] && _tMangleOption='-t mangle'
}

[ -z "$YAMON" ] && loadconfig