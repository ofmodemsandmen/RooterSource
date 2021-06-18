#!/bin/sh

log() {
	logger -t "modem-led " "$@"
}

CURRMODEM=$1
COMMD=$2

DEV=$(uci get modem.modem$CURRMODEM.device)
DEVV=${DEV:0:5}

if [ $DEVV = "1-2.4" ]; then
	case $COMMD in
		"0" )
			echo none > /sys/class/leds/modem1_blue/trigger
			echo 0  > /sys/class/leds/modem1_blue/brightness
			;;
		"1" )
			echo timer > /sys/class/leds/modem1_blue/trigger
			echo 500  > /sys/class/leds/modem1_blue/delay_on
			echo 500  > /sys/class/leds/modem1_blue/delay_off
			;;
		"2" )
			echo timer > /sys/class/leds/modem1_blue/trigger
			echo 200  > /sys/class/leds/modem1_blue/delay_on
			echo 200  > /sys/class/leds/modem1_blue/delay_off
			;;
		"3" )
			echo timer > /sys/class/leds/modem1_blue/trigger
			echo 1000  > /sys/class/leds/modem1_blue/delay_on
			echo 0  > /sys/class/leds/modem1_blue/delay_off
			;;
		"4" )
			echo none > /sys/class/leds/modem1_blue/trigger
			echo 1  > /sys/class/leds/modem1_blue/brightness
			;;
	esac
else
	case $COMMD in
		"0" )
			echo none > /sys/class/leds/modem2_blue/trigger
			echo 0  > /sys/class/leds/modem2_blue/brightness
			;;
		"1" )
			echo timer > /sys/class/leds/modem2_blue/trigger
			echo 500  > /sys/class/leds/modem2_blue/delay_on
			echo 500  > /sys/class/leds/modem2_blue/delay_off
			;;
		"2" )
			echo timer > /sys/class/leds/modem2_blue/trigger
			echo 200  > /sys/class/leds/modem2_blue/delay_on
			echo 200  > /sys/class/leds/modem2_blue/delay_off
			;;
		"3" )
			echo timer > /sys/class/leds/modem2_blue/trigger
			echo 1000  > /sys/class/leds/modem2_blue/delay_on
			echo 0  > /sys/class/leds/modem2_blue/delay_off
			;;
		"4" )
			echo none > /sys/class/leds/modem2_blue/trigger
			echo 1  > /sys/class/leds/modem2_blue/brightness
			;;
	esac

fi