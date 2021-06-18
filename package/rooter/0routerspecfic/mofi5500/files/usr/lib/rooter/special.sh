#!/bin/sh

echo "none" > /sys/class/leds/modem1_pwr/trigger
echo "1" > /sys/class/leds/modem1_pwr/brightness

echo "none" > /sys/class/leds/modem2_pwr/trigger
echo "1" > /sys/class/leds/modem2_pwr/brightness
		