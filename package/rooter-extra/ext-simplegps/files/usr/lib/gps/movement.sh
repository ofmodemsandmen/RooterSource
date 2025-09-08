#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "Motion Report" "$@"
}

readll() {
	while IFS= read -r line; do
		date=$line
		read -r line
		altitude=$line
		read -r line
		latitude=$line
		read -r line
		longitude=$line
		read -r line
		numsat=$line
		read -r line
		horizp=$$line
		read -r line
		fix=$line
		read -r line
		heading=$line
		read -r line
		hspd=$line
		read -r line
		vspd=$line
		read -r line
		dlatitude=$line
		read -r line
		dlongitude=$line
		break
	done < /tmp/gpsdata
}

baseflag="0"
move="0"
while true
do
	if [ -e /tmp/gps ]; then
		if [ -e /tmp/gpsdata ]; then
			refresh=$(uci -q get gps.configuration.refresh)
			readll
			if [ $baseflag = "0" ]; then
				baseflag="1"
				baselat=$dlatitude
				baselon=$dlongitude
				sleep $refresh
				sleep 5
				readll
			fi
			precision=$(uci -q get gps.configuration.precision)
			/usr/lib/gps/compare.lua $baselat $baselon $dlatitude $dlongitude $precision
			source /tmp/compare
			if [ $COMPARE = "1" ]; then
				move="1"
				if [ $baseflag = "1" ]; then
					baseflag="2"
					/usr/lib/gps/sendreport.sh 1 $baselat $baselon
					STARTIMEX=$(date +%s)
					move="0"
					pbaselat=$dlatitude
					pbaselon=$dlongitude
				fi
				CURRTIME=$(date +%s)
				let ELAPSE=CURRTIME-STARTIMEX
				interval=$(uci -q get gps.configuration.minterval)
				let interval=interval*60
				if [ $ELAPSE -ge $interval ]; then
					/usr/lib/gps/sendreport.sh 1 $baselat $baselon
					STARTIMEX=$CURRTIME
					move="0"
					pbaselat=$dlatitude
					pbaselon=$dlongitude
				fi
				baselat=$dlatitude
				baselon=$dlongitude
			else
				if [ $move = "1" ]; then
					CURRTIME=$(date +%s)
					let ELAPSE=CURRTIME-STARTIMEX
					interval=$(uci -q get gps.configuration.minterval)
					let interval=interval*60
					if [ $ELAPSE -ge $interval ]; then
						/usr/lib/gps/sendreport.sh 2 $pbaselat $pbaselon
						STARTIMEX=$CURRTIME
						move="0"
					fi
				fi
			fi
		fi
		sleep 60
	else
		exit 0
	fi
done
