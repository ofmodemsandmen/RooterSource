local fs = require "nixio.fs"
local util = require "nixio.util"

m = Map("bwmon", translate("Bandwidth Monitoring"), translate("Monitor bandwidth by Device"))

m.on_after_save = function(self)
	luci.sys.call("/opt/WRTbmon/process.sh &")
end

s=m:section(TypedSection, "bwmon", translate("Settings"))
s.addremove=false
s.anonymous=true

enable=s:option(Flag, "enabled", translate("Enabled"), translate("Monitor must be enabled in order to gather data displayed on this page"))
enable.rmempty=false

unlimit = s:option(ListValue, "unlimited_usage", translate("Unlimited Usage Available :"), translate("You are allowed to use unlimited bandwidth without charge at specific times of day. This bandwidth is not included in the totals"))
unlimit.rmempty = true
unlimit:value("0", "No")
unlimit:value("1", "Yes")
unlimit.default = "0"

sdhour = s:option(ListValue, "unlimited_start", translate("Unlimited Start Time :"))
sdhour.rmempty = true
sdhour:value("0:00", "12:00 AM")
sdhour:value("0:15", "12:15 AM")
sdhour:value("0:30", "12:30 AM")
sdhour:value("0:45", "12:45 AM")
sdhour:value("1:00", "01:00 AM")
sdhour:value("1:15", "01:15 AM")
sdhour:value("1:30", "01:30 AM")
sdhour:value("1:45", "01:45 AM")
sdhour:value("2:00", "02:00 AM")
sdhour:value("2:15", "02:15 AM")
sdhour:value("2:30", "02:30 AM")
sdhour:value("2:45", "02:45 AM")
sdhour:value("3:00", "03:00 AM")
sdhour:value("3:15", "03:15 AM")
sdhour:value("3:30", "03:30 AM")
sdhour:value("3:45", "03:45 AM")
sdhour:value("4:00", "04:00 AM")
sdhour:value("4:15", "04:15 AM")
sdhour:value("4:30", "04:30 AM")
sdhour:value("4:45", "04:45 AM")
sdhour:value("5:00", "05:00 AM")
sdhour:value("5:15", "05:15 AM")
sdhour:value("5:30", "05:30 AM")
sdhour:value("5:45", "05:45 AM")
sdhour:value("6:00", "06:00 AM")
sdhour:value("6:15", "06:15 AM")
sdhour:value("6:30", "06:30 AM")
sdhour:value("6:45", "06:45 AM")
sdhour:value("7:00", "07:00 AM")
sdhour:value("7:15", "07:15 AM")
sdhour:value("7:30", "07:30 AM")
sdhour:value("7:45", "07:45 AM")
sdhour:value("8:00", "08:00 AM")
sdhour:value("8:15", "08:15 AM")
sdhour:value("8:30", "08:30 AM")
sdhour:value("8:45", "08:45 AM")
sdhour:value("9:00", "09:00 AM")
sdhour:value("9:15", "09:15 AM")
sdhour:value("9:30", "09:30 AM")
sdhour:value("9:45", "09:45 AM")
sdhour:value("10:00", "10:00 AM")
sdhour:value("10:15", "10:15 AM")
sdhour:value("10:30", "10:30 AM")
sdhour:value("10:45", "10:45 AM")
sdhour:value("11:00", "11:00 AM")
sdhour:value("11:15", "11:15 AM")
sdhour:value("11:30", "11:30 AM")
sdhour:value("11:45", "11:45 AM")
sdhour:value("12:00", "12:00 PM")
sdhour:value("12:15", "12:15 PM")
sdhour:value("12:30", "12:30 PM")
sdhour:value("12:45", "12:45 PM")
sdhour:value("13:00", "01:00 PM")
sdhour:value("13:15", "01:15 PM")
sdhour:value("13:30", "01:30 PM")
sdhour:value("13:45", "01:45 PM")
sdhour:value("14:00", "02:00 PM")
sdhour:value("14:15", "02:15 PM")
sdhour:value("14:30", "02:30 PM")
sdhour:value("14:45", "02:45 PM")
sdhour:value("15:00", "03:00 PM")
sdhour:value("15:15", "03:15 PM")
sdhour:value("15:30", "03:30 PM")
sdhour:value("15:45", "03:45 PM")
sdhour:value("16:00", "04:00 PM")
sdhour:value("16:15", "04:15 PM")
sdhour:value("16:30", "04:30 PM")
sdhour:value("16:45", "04:45 PM")
sdhour:value("17:00", "05:00 PM")
sdhour:value("17:15", "05:15 PM")
sdhour:value("17:30", "05:30 PM")
sdhour:value("17:45", "05:45 PM")
sdhour:value("18:00", "06:00 PM")
sdhour:value("18:15", "06:15 PM")
sdhour:value("18:30", "06:30 PM")
sdhour:value("18:45", "06:45 PM")
sdhour:value("19:00", "07:00 PM")
sdhour:value("19:15", "07:15 PM")
sdhour:value("19:30", "07:30 PM")
sdhour:value("19:45", "07:45 PM")
sdhour:value("20:00", "08:00 PM")
sdhour:value("20:15", "08:15 PM")
sdhour:value("20:30", "08:30 PM")
sdhour:value("20:45", "08:45 PM")
sdhour:value("21:00", "09:00 PM")
sdhour:value("21:15", "09:15 PM")
sdhour:value("21:30", "09:30 PM")
sdhour:value("21:45", "09:45 PM")
sdhour:value("22:00", "10:00 PM")
sdhour:value("22:15", "10:15 PM")
sdhour:value("22:30", "10:30 PM")
sdhour:value("22:45", "10:45 PM")
sdhour:value("23:00", "11:00 PM")
sdhour:value("23:15", "11:15 PM")
sdhour:value("23:30", "11:30 PM")
sdhour:value("23:45", "11:45 PM")

sdhour:depends("unlimited_usage", "1")
sdhour.default = "0:00"

edhour = s:option(ListValue, "unlimited_end", translate("Unlimited End Time :"))
edhour.rmempty = true
edhour:value("0:00", "12:00 AM")
edhour:value("0:15", "12:15 AM")
edhour:value("0:30", "12:30 AM")
edhour:value("0:45", "12:45 AM")
edhour:value("1:00", "01:00 AM")
edhour:value("1:15", "01:15 AM")
edhour:value("1:30", "01:30 AM")
edhour:value("1:45", "01:45 AM")
edhour:value("2:00", "02:00 AM")
edhour:value("2:15", "02:15 AM")
edhour:value("2:30", "02:30 AM")
edhour:value("2:45", "02:45 AM")
edhour:value("3:00", "03:00 AM")
edhour:value("3:15", "03:15 AM")
edhour:value("3:30", "03:30 AM")
edhour:value("3:45", "03:45 AM")
edhour:value("4:00", "04:00 AM")
edhour:value("4:15", "04:15 AM")
edhour:value("4:30", "04:30 AM")
edhour:value("4:45", "04:45 AM")
edhour:value("5:00", "05:00 AM")
edhour:value("5:15", "05:15 AM")
edhour:value("5:30", "05:30 AM")
edhour:value("5:45", "05:45 AM")
edhour:value("6:00", "06:00 AM")
edhour:value("6:15", "06:15 AM")
edhour:value("6:30", "06:30 AM")
edhour:value("6:45", "06:45 AM")
edhour:value("7:00", "07:00 AM")
edhour:value("7:15", "07:15 AM")
edhour:value("7:30", "07:30 AM")
edhour:value("7:45", "07:45 AM")
edhour:value("8:00", "08:00 AM")
edhour:value("8:15", "08:15 AM")
edhour:value("8:30", "08:30 AM")
edhour:value("8:45", "08:45 AM")
edhour:value("9:00", "09:00 AM")
edhour:value("9:15", "09:15 AM")
edhour:value("9:30", "09:30 AM")
edhour:value("9:45", "09:45 AM")
edhour:value("10:00", "10:00 AM")
edhour:value("10:15", "10:15 AM")
edhour:value("10:30", "10:30 AM")
edhour:value("10:45", "10:45 AM")
edhour:value("11:00", "11:00 AM")
edhour:value("11:15", "11:15 AM")
edhour:value("11:30", "11:30 AM")
edhour:value("11:45", "11:45 AM")
edhour:value("12:00", "12:00 PM")
edhour:value("12:15", "12:15 PM")
edhour:value("12:30", "12:30 PM")
edhour:value("12:45", "12:45 PM")
edhour:value("13:00", "01:00 PM")
edhour:value("13:15", "01:15 PM")
edhour:value("13:30", "01:30 PM")
edhour:value("13:45", "01:45 PM")
edhour:value("14:00", "02:00 PM")
edhour:value("14:15", "02:15 PM")
edhour:value("14:30", "02:30 PM")
edhour:value("14:45", "02:45 PM")
edhour:value("15:00", "03:00 PM")
edhour:value("15:15", "03:15 PM")
edhour:value("15:30", "03:30 PM")
edhour:value("15:45", "03:45 PM")
edhour:value("16:00", "04:00 PM")
edhour:value("16:15", "04:15 PM")
edhour:value("16:30", "04:30 PM")
edhour:value("16:45", "04:45 PM")
edhour:value("17:00", "05:00 PM")
edhour:value("17:15", "05:15 PM")
edhour:value("17:30", "05:30 PM")
edhour:value("17:45", "05:45 PM")
edhour:value("18:00", "06:00 PM")
edhour:value("18:15", "06:15 PM")
edhour:value("18:30", "06:30 PM")
edhour:value("18:45", "06:45 PM")
edhour:value("19:00", "07:00 PM")
edhour:value("19:15", "07:15 PM")
edhour:value("19:30", "07:30 PM")
edhour:value("19:45", "07:45 PM")
edhour:value("20:00", "08:00 PM")
edhour:value("20:15", "08:15 PM")
edhour:value("20:30", "08:30 PM")
edhour:value("20:45", "08:45 PM")
edhour:value("21:00", "09:00 PM")
edhour:value("21:15", "09:15 PM")
edhour:value("21:30", "09:30 PM")
edhour:value("21:45", "09:45 PM")
edhour:value("22:00", "10:00 PM")
edhour:value("22:15", "10:15 PM")
edhour:value("22:30", "10:30 PM")
edhour:value("22:45", "10:45 PM")
edhour:value("23:00", "11:00 PM")
edhour:value("23:15", "11:15 PM")
edhour:value("23:30", "11:30 PM")
edhour:value("23:45", "11:45 PM")

edhour:depends("unlimited_usage", "1")
edhour.default = "8:00"

--m:section(SimpleSection).template = "rooter/bandw"

sx = m:section(TypedSection, "bwmon", "Data Usage")
sx.anonymous = true

function pad(strng, tabs)
	len = string.len(strng)
	tabx = tabs - math.floor((len) / 4)
	tabstr = string.rep("\t", tabx)
	--if tabs > 0 then
		--tabx = string.rep(" ", 32)
	--namstr = string.rep("+", 24)
	--if tabx > 0 then
		strng = strng .. tabstr
		--else
		--strng = strng .. "\t"
	--end
	--strng = strng:sub(1,32)
	--strng = strng .. tabstr
	--strng = strng:sub(1,(tabs * 8) + 24) .. " "
	return strng
end

function calc(total)
	if total < 1000 then
		tstr = string.format("%10.2f", total)
		tfm = " K"
	else
		if total < 1000000 then
			tstr = string.format("%10.2f", total/1000)
			tfm = " MB"
		else
			tstr = string.format("%10.2f", total/1000000)
			tfm = " GB"
		end
	end
	str = tstr .. tfm
	str = string.rep(" ", 16) .. str
	--str = str:sub(-16)
	str = string.sub(str, -14)
	return str
end

function monthly(datafile)
	file = io.open(datafile, "r")
	i = 0
	dayx = 0
	repeat
		line = file:read("*line")
		if line == nil then
			break
		end
		s, e = line:find("start day")
		if s ~= nil then
				dayx = dayx + 1
				repeat
					line = file:read("*line")
					s, e = line:find("end day")
					if s ~= nil then
						break
					end
					s, e = line:find("\"mac\":\"")
					bs, be = line:find("\"", e+1)
					mac = line:sub(e+1, bs-1)
					if bw[mac] == nil then
						maclist[i] = mac
						i = i + 1
						bw[mac] = {}
						bw[mac]['down'] = 0
						bw[mac]['offdown'] = 0
						bw[mac]['up'] = 0
						bw[mac]['offup'] = 0
					end
					s, e = line:find("\"down\":\"")
					bs, be = line:find("\"", e+1)
					down = tonumber(line:sub(e+1, bs-1))
					bw[mac]['down'] = bw[mac]['down'] + down
					s, e = line:find("\"up\":\"")
					bs, be = line:find("\"", e+1)
					up = tonumber(line:sub(e+1, bs-1))
					bw[mac]['up'] = bw[mac]['up'] + up
					s, e = line:find("\"offdown\":\"")
					bs, be = line:find("\"", e+1)
					offdown = tonumber(line:sub(e+1, bs-1))
					bw[mac]['offdown'] = bw[mac]['offdown'] + offdown
					s, e = line:find("\"offup\":\"")
					bs, be = line:find("\"", e+1)
					offup = tonumber(line:sub(e+1, bs-1))
					bw[mac]['offup'] = bw[mac]['offup'] + offup
					s, e = line:find("\"ip\":\"")
					bs, be = line:find("\"", e+1)
					bw[mac]['ip'] = line:sub(e+1, bs-1)
					s, e = line:find("\"name\":\"")
					bs, be = line:find("\"", e+1)
					bw[mac]['name'] = line:sub(e+1, bs-1)
				until 1==0
		end					
	until 1==0
	file:close()
	return dayx
end

function showdevices(bw, maclist)
	devices = "---DEVICES---\n\n" .. "IP ADDRESS\t\tMAC ADDRESS\t\tDOWNLOADS\t\t  UPLOADS\t\t     TOTAL\t\t\tDEVICE NAME\n" .. string.rep("_", 120) .. "\n\n"
	k = 0
	while maclist[k] ~= nil do
		k = k + 1
	end
	if k > 0 then
		j = 0
		while maclist[j] ~= nil do
			dtot = bw[maclist[j]]['down'] + bw[maclist[j]]['up']
			devices = devices .. pad(bw[maclist[j]]['ip'], 5) .. pad(maclist[j],5) .. "\t"
			devices = devices .. pad(calc(bw[maclist[j]]['down']), 2) .. "\t\t" .. pad(calc(bw[maclist[j]]['up']), 2) .. "\t\t"
			devices = devices .. pad(calc(dtot), 2) .. "\t\t" .. pad(bw[maclist[j]]['name'], 6) .. "\n"
			
			j = j + 1
		end
	end
	return devices
end

function totals(bw, maclist, dayz)
	totaldown = 0
	totalup = 0
	utotaldown = 0
	utotalup = 0
	j=0
	while maclist[j] ~= nil do
		totaldown = totaldown + bw[maclist[j]]['down']
		totalup = totalup + bw[maclist[j]]['up']
		utotaldown = utotaldown + bw[maclist[j]]['offdown']
		utotalup = utotalup + bw[maclist[j]]['offup']
		j = j + 1
	end
	total = totalup + totaldown
	ptotal = (total / dayz) * 30
	totaline = "  # of Days : " .. string.format("%d", dayz) .."\n\n  Download : " .. calc(totaldown) .. "\t\t  Upload : " .. calc(totalup) .. "\t\t  Total : " .. calc(total) .. "\t\t   Projected Monthly Total : " .. calc(ptotal) .. "\n\n\n"
	ttotals = "---METERED TOTALS---\n\n" .. totaline
	utotal = utotalup + utotaldown
	if utotal > 0 then
		utotaline = "   DOWNLOAD : " .. calc(utotaldown) .. "\tUPLOAD : " .. calc(utotalup) .. "\tTOTALS : " .. calc(utotal) .. "\n\n\n"
		ttotals = ttotals .. "---UNMETERED TOTALS---\n\n" .. utotaline
	end
	return ttotals
end

months = {}
days = {}
nummon = 0
tabname = {}
totline = {}
devline = {}
dirname = '/opt/WRTbmon/data'
filepost = "-mac_data.js"

f = io.popen('/bin/ls ' .. dirname)
for name in f:lines() do 
	s, e = name:find(filepost)
	if s ~= nil then
		nummon = nummon + 1
		months[nummon] = dirname .. "/" .. name
		tabname[nummon] = name:sub(1, s-1)
	end
end
f:close()

linex = {}

if nummon > 0 then
	for i=nummon,1,-1 do
		bw = {}
		maclist = {}
		days[i] = monthly(months[i])
		totline[i] = totals(bw, maclist, days[i])
		devline[i] = showdevices(bw, maclist)
		monx = string.format("mon%d", i)
		sx:tab(monx,  translate("Month of " .. tabname[i]))
	end
end

if nummon > 0 then
	line1 = sx:taboption("mon1", TextValue, "", translate(""))
	line1.readonly=true
	line1.wrap    = "off"
	line1.rows    = 30
	line1.rmempty = false
	function line1.cfgvalue(self, s)
			return totline[1] .. devline[1]
	end
else
	line0 = sx:option(DummyValue, "", translate("No Data Available"))
end

if nummon > 1 then
	line2 = sx:taboption("mon2", TextValue, "", translate(""))
	line2.readonly=true
	line2.wrap    = "off"
	line2.rows    = 30
	line2.rmempty = false
	function line2.cfgvalue(self, s)
			return totline[2] .. devline[2]
	end
end

if nummon > 2 then
	line3 = sx:taboption("mon3", TextValue, "", translate(""))
	line3.readonly=true
	line3.wrap    = "off"
	line3.rows    = 30
	line3.rmempty = false
	function line3.cfgvalue(self, s)
			return totline[3] .. devline[3]
	end
end

return m