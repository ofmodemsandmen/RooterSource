#!/bin/sh

log() {
	logger -t "YAMon 3 Data Cleanup : " "$@"
}

PRE="/usr/lib/YAMon3/data/"
CURRENT=""
LAST=""

del_last() {
	if [ ! -z $LAST ]; then
		rm -rf "$PRE$LAST"
	fi
}

del_extra() {
	CURR=$1
	min_dirs=$2
	
	tot_dir=$(find "$PRE$CURR" -maxdepth 1 -type d | wc -l)
	let tot_dir=tot_dir-1
	
	if [ $tot_dir -gt $min_dirs ]; then
		let num_del=tot_dir-min_dirs
		for i in $(ls -d $PRE$CURR/*/); do 
			LID=${i%%/}
			LID=${LID#"$PRE$CURR/"}
			rm -rf "$PRE$CURR/$LID"
			let num_del=num_del-1
			if [ $num_del -eq 0 ]; then
				return
			fi
		done
	fi
}

for i in $(ls -d $PRE/*/); do 
	LI=${i%%/}
	LI=${LI#"$PRE/"}
	if [ -z $CURRENT ]; then
		CURRENT=$LI
	else
		if [ $LI > $CURRENT ]; then
			LAST=$CURRENT
			CURRENT=$LI
		else
			LAST=$LI
		fi
	fi
done

if [ ! -z $CURRENT ]; then
	CCOUNT=0
	for i in $(ls -d $PRE$CURRENT/*/); do 
		LI=${i%%/}
		LI=${LI#"$PRE$CURRENT/"}
		let CCOUNT=CCOUNT+1
	done
	if [ $CCOUNT -gt 3 ]; then
		del_extra $CURRENT 3
		del_last
	else
		if [ $CCOUNT -eq 3 ]; then
			del_last
		else
			if [ ! -z $LAST ]; then	
			COUNT=$CCOUNT
				for i in $(ls -d $PRE$LAST/*/); do 
					LI=${i%%/}
					LI=${LI#"$PRE$LAST/"}
					let CCOUNT=CCOUNT+1
				done
				if [ $CCOUNT -gt 3 ]; then
					let CNT=3-COUNT
					del_extra $LAST $CNT
				fi
			fi			
		fi
	fi
fi