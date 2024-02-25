#!/bin/sh

log() {
	modlog "Check Connection $CURRMODEM" "$@"
}

result=`ps w | grep -i "chkconn1.sh $1" | grep -v "grep" | wc -l`
if [ "$result" -lt 1 ]; then
	/usr/lib/rooter/connect/chkconn1.sh $1 &
fi