#!/bin/sh

log() {
	modlog "modem-led " "$@"
}

CURRMODEM=$1
COMMD=$2
sig2=$3

DEV=$(uci get modem.modem$CURRMODEM.device)
if [ $DEV = "1-1.2" ]; then
	case $COMMD in
		"0" )
			gl_uart 474c190100
			;;
		"1" )
			gl_uart 474c190101
			;;
		"2" )
			gl_uart 474c190103
			;;
		"3" )
			gl_uart 474c190107
			;;
		"4" )
			if [ $sig2 -lt 5 -a $sig2 -ge 0 ] 2>/dev/null;then
				gl_uart 474c190100
			elif [ $sig2 -ge 5 -a $sig2 -lt 10 ] 2>/dev/null;then
				gl_uart 474c190101
			elif [ $sig2 -ge 10 -a $sig2 -lt 20 ] 2>/dev/null;then
				gl_uart 474c190103
			elif [ $sig2 -ge 20 -a $sig2 -le 31 ] 2>/dev/null;then
				gl_uart 474c190107
			elif [ $sig2 -gt 31 ] 2>/dev/null;then
				gl_uart 474c190107
			fi
			;;
	esac
else
	if [ $DEV = "2-1.2" ]; then
		case $COMMD in
			"0" )
				gl_uart 474c1a0100
				;;
			"1" )
				gl_uart 474c1a0108
				;;
			"2" )
				gl_uart 474c1a0118
				;;
			"3" )
				gl_uart 474c1a0138
				;;
			"4" )
				if [ $sig2 -lt 5 -a $sig2 -ge 0 ] 2>/dev/null;then
					gl_uart 474c1a0100
				elif [ $sig2 -ge 5 -a $sig2 -lt 10 ] 2>/dev/null;then
					gl_uart 474c1a0108
				elif [ $sig2 -ge 10 -a $sig2 -lt 20 ] 2>/dev/null;then
					gl_uart 474c1a0118
				elif [ $sig2 -ge 20 -a $sig2 -le 31 ] 2>/dev/null;then
					gl_uart 474c1a0138
				elif [ $sig2 -gt 31 ] 2>/dev/null;then
					gl_uart 474c1a0138
				fi
				;;
		esac
	fi
fi