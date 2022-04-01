#!/bin/sh

ROOTER=/usr/lib/rooter

COPS=$1
PROV=$(echo "$1" | awk '{print tolower($0)}')
if [ $PROV = "cricket" ]; then
	COPS="AT&T"
fi
CURRMODEM=$2
{
	echo 'COPS="'"$COPS"'"'
} > /tmp/cops$CURRMODEM.file