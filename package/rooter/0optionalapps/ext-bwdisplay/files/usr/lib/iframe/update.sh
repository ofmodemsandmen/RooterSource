#!/bin/sh
. /lib/functions.sh

copy_text() {
	text=$1
	align=$2
	
	txt="<p style=\"color: black; font-family: arial, helvetica, sans-serif; "
	txt=$txt"text-align: "$align";\">"
	txt=$txt"$1""</p>"
	echo "$txt" >> /tmp/www/temp

}

copy_top() {
	title="$1"
	echo '<?xml version="1.0" encoding="utf-8"?>' > /tmp/www/temp 
	echo '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">' >> /tmp/www/temp
	echo '<html xmlns="http://www.w3.org/1999/xhtml">' >> /tmp/www/temp
	echo '<head>' >> /tmp/www/temp
	echo '<meta http-equiv="refresh" content="300">' >> /tmp/www/temp
	echo '</head>' >> /tmp/www/temp
	echo '<body style="background-color: lightgrey">' >> /tmp/www/temp
	if [ ! -z "$title" ]; then
		copy_text "$title" "center"
	fi
}

bwdata() {
	while IFS= read -r line; do
		if [ $line = '0' ]; then
			nodata="1"
			break
		else
			nodata="0"
			days=$line
			read -r line
			read -r line
			tused=$line
			read -r line
			read -r line
			tdwn=$line
			read -r line
			read -r line
			tup=$line
			read -r line
			read -r line
			project=$line
			break
		fi
	done < /tmp/bwdata
}

if [ -e /etc/iframe ]; then
	if [ ! -d /tmp/www ]; then
		mkdir -p /tmp/www
	fi
	bwdata
	copy_top "<strong>Bandwidth Usage</strong>"
	if [ $nodata = "1" ]; then
		copy_text "No Data Availiable" "left"
	else
		copy_text "Days in Reporting Period : $days" "left"
		copy_text "Total Bandwidth Used : $tused" "left"
		copy_text "Total Download : $tdwn" "left"
		copy_text "Total Upload : $tup" "left"
		copy_text "Projected Usage : $project" "left"
	fi
 
	echo "</body>" >> /tmp/www/temp
	echo "</html>" >> /tmp/www/temp
	mv /tmp/www/temp /tmp/www/display.html
fi