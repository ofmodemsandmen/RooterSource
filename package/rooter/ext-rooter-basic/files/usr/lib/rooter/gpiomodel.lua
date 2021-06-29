#!/usr/bin/lua

mfile = "/tmp/sysinfo/model"
echo = 1
model = {}
gpio = {}
gpio2 = {}
gpio3 = {}
gpio4 = {}
gpioname = {}
gpioname2 = {}
gpioname3 = {}
gpioname4 = {}

pin = nil
pin2 = nil

model[1] = "703n"
gpio[1] = 8
model[2] = "3020"
gpio[2] = 8
model[3] = "11u"
gpio[3] = 8
model[4] = "3040"
gpio[4] = 18
model[5] = "3220"
gpio[5] = 6
model[6] = "3420"
gpio[6] = 6
model[7] = "wdr3500"
gpio[7] = 12
gpioname[7] = "tp-link:power:usb"
model[8] = "wdr3600"
gpio[8] = 22
gpioname[8] = "tp-link:power:usb1"
gpio2[8] = 21
gpioname2[8] = "tp-link:power:usb2"
model[9] = "wdr4300"
gpio[9] = 22
gpioname[9] = "tp-link:power:usb1"
gpio2[9] = 21
gpioname2[9] = "tp-link:power:usb2"
model[10] = "wdr4310"
gpio[10] = 22
gpioname2[10] = "tp-link:power:usb2"
gpioname[10] = "tp-link:power:usb1"
gpio2[10] = 21
model[11] = "842"
gpio[11] = 6
gpioname[11] = "tp-link:power:usb"
model[12] = "13u"
gpio[12] = 18
model[13] = "710n"
gpio[13] = 8
model[14] = "10u"
gpio[14] = 18
model[15] = "oolite"
gpio[15] = 18
model[16] = "720"
gpio[16] = 8
model[17] = "1043"
gpio[17] = 21
gpioname[17] = "tp-link:power:usb"
model[18] = "4530"
gpio[18] = 22
model[19] = "archer"
gpio[19] = 22
gpio2[19] = 21
gpioname2[19] = "tp-link:power:usb2"
gpioname[19] = "tp-link:power:usb1"
model[20] = "ar150"
gpio[20] = 6
model[21] = "domino"
gpio[21] = 6
model[22] = "300a"
gpio[22] = 0
model[23] = "300n"
gpio[23] = 0
model[24] = "wdr4900"
gpio[24] = 10
model[25] = "7800"
gpio[25] = 15
gpio2[25] = 16
model[26] = "m33g"
gpio[26] = 9
gpio2[26] = 10
gpio3[26] = 11
gpio4[26] = 12
gpioname[26] = "gpio9"
gpioname2[26] = "gpio10"
gpioname3[26] = "gpio11"
gpioname4[26] = "gpio12"
model[27] = "m11g"
gpio[27] = 9
gpioname[27] = "gpio9"
model[28] = "ap147"
gpio[28] = 13
model[29] = "ar750s"
gpio[29] = 7
model[30] = "mt300n-v2"
gpio[30] = 11
gpioname[30] = "usb"
model[31] = "gigamod"
gpio[31] = 16
gpioname[31] = "power_usb"
model[32] = "turbomod"
gpio[32] = 17
gpioname[32] = "power_usb"

numodel = 32

local file = io.open(mfile, "r")
if file == nil then
	return
end

name = nil
name2 = nil
line = file:read("*line")
file:close()
line = line:lower()

for i=1,numodel do
	start, ends = line:find(model[i])
	if start ~= nil then
		if model[i] == "3420" then
			start, ends = line:find("v1")
			if start ~= nil then
				pin = gpio[i]
				pin2 = nil
			else
				pin = 4
				pin2 = nil
			end
		else
			if model[i] == "3220" then
				start, ends = line:find("v1")
				if start ~= nil then
					pin = gpio[i]
					pin2 = nil
				else
					pin = 8
					pin2 = nil
				end
			else
				if model[i] == "1043" then
					start, ends = line:find("v2")
					if start ~= nil then
						pin = gpio[i]
						pin2 = nil
						name = gpioname[i]
						name2 = nil
					end
				else
					if model[i] == "842" then
						start, ends = line:find("v3")
						if start == nil then
							start, ends = line:find("v2")
							if start == nil then
								pin = gpio[i]
								pin2 = gpio2[i]
								name = gpioname[i]
								name2 = gpioname2[i]
							else
								pin = 4
								pin2 = nil
								name = gpioname[i]
								name2 = nil
							end
						end
					else
						if model[i] == "archer" then
							start, ends = line:find("c20")
							if start == nil then
								pin = gpio[i]
								pin2 = gpio2[i]
								name = gpioname[i]
								name2 = gpioname2[i]
							end
						else
							pin = gpio[i]
							pin2 = gpio2[i]
							name = gpioname[i]
							name2 = gpioname2[i]
						end
					end
				end
			end
		end
		
		break
	end
end

if pin ~= nil then
	local tfile = io.open("/tmp/gpiopin", "w")
	if pin2 ~= nil then
		tfile:write("GPIOPIN=\"", pin, "\"\n")
		tfile:write("GPIOPIN2=\"", pin2, "\"")
	else
		tfile:write("GPIOPIN=\"", pin, "\"")
	end
	tfile:close()
end
if name ~= nil then
	local tfile = io.open("/tmp/gpioname", "w")
	if name2 ~= nil then
		tfile:write("GPIONAME=\"", name, "\"\n")
		tfile:write("GPIONAME2=\"", name2, "\"")
	else
		tfile:write("GPIONAME=\"", name, "\"")
	end
	tfile:close()
end
