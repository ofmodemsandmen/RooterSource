##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# getLocalCopies - makes a local copy of the usage-monitor.com JS & CSS files
#
##########################################################################

getFile()
{
	local src="$1"
	local dst="$2"
	$send2log ">>> local copies $src $dst" -1
	if [ -x /usr/bin/curl ] ; then
		curl -sk --max-time 15 -o "$dst" --header "Pragma: no-cache" --header "Cache-Control: no-cache" -A YAMon-Setup "$src"
	else
		wget "$src" -qO "$dst"
	fi
}

getLocalCopies()
{
	$send2log "=== Getting a local copy of JS & CSS files === $_doLocalFiles" 1
	local path="${d_baseDir}/$_setupWebDir"
	path=${path%/}
	local webpath="$_wwwPath$_wwwJS"
	webpath=${webpath%/}
	local web="http://usage-monitoring.com/current"

	$send2log ">>> local copies " 0
	getFile "$web/js/yamon$_file_version.js" "$webpath/yamon$_file_version.js"
	getFile "$web/js/util$_file_version.js" "$webpath/util$_file_version.js"
	[ ! "$_settings_pswd" == "" ] && getFile "$web/js/jquery.md5.min.js" "$webpath/jquery.md5.min.js"
	getFile "$web/css/normalize.css" "$path/css/normalize.css"
	getFile "$web/css/yamon$_file_version.css" "$path/css/yamon$_file_version.css"
	$send2log ">>> Downloading images:" 0
	
	imageList="favicon.png,yamon-logo.png,waiting.gif,buttons.png,tabs.png,paypal.png,icons.png,edit.png,flags16.png"
	IFS=","
	for v in $(echo "$imageList")
	do
		getFile "$web/images/$v" "$path/images/$v"
	done
	$send2log ">>> local copy done" -1
}
