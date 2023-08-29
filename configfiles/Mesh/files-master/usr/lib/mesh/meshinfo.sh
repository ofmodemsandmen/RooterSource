#!/bin/sh
. /lib/functions.sh

dmp=$(iw dev mesh0 station dump)
if [ ! -z "$dmp" ]; then
	echo "$dmp" > /tmp/dmp
	msh=""
	while IFS= read -r line; do
		station=$(echo "$line" | grep "Station")
		station=$(echo "$station" | tr " " ",")
		mac=$(echo $station | cut -d, -f2)
		msh=$msh$mac"|"
		for i in $(seq 1 40);
		do
			read -r line
			rxb=$(echo "$line" | grep "rx bytes")
			if [ ! -z "$rxb" ]; then
				rxb=$(echo "$rxb" | tr " " ",")
				rxb=${rxb:10}
				msh=$msh$rxb"|"
			fi
			txb=$(echo "$line" | grep "tx bytes")
			if [ ! -z "$txb" ]; then
				txb=$(echo "$txb" | tr " " ",")
				txb=${txb:10}
				msh=$msh$txb"|"
			fi
			sa=$(echo "$line" | grep "signal avg:")
			if [ ! -z "$sa" ]; then
				sa=$(echo "$sa" | tr " " ",")
				sa=$(echo $sa | cut -d, -f2)
				sa=${sa:5}
				msh=$msh$sa"|"
			fi
			tbit=$(echo "$line" | grep "tx bitrate:")
			if [ ! -z "$tbit" ]; then
				tbit=${tbit:12}
				msh=$msh$tbit"|"
			fi
			rbit=$(echo "$line" | grep "rx bitrate:")
			if [ ! -z "$rbit" ]; then
				rbit=${rbit:12}
				msh=$msh$rbit"|"
			fi
			tp=$(echo "$line" | grep "expected throughput:")
			if [ ! -z "$tp" ]; then
				tp=${tp:21}
				msh=$msh$tp"|"
			fi
		done
	done < /tmp/dmp	
	echo "$msh" > /tmp/dmp
fi