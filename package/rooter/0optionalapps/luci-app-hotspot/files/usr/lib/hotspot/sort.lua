#!/usr/bin/lua

hotlist = "/etc/hotspot"
ssidlist = "/tmp/ssidlist"
newlist = "/tmp/hotspot"

local ssid = {}
local hot = {}
local hotstrength = {}

file = io.open(hotlist, "r")
if file == nil then
	return
end
i = 1
repeat
	line = file:read("*line")
	if line == nil then
		break
	end
	hot[i] = line
	i = i + 1
until false
file:close()

file = io.open(ssidlist, "r")
if file == nil then
	return
end
j = 1
repeat
	line = file:read("*line")
	if line == nil then
		break
	end
	ssid[j] = line
	j = j + 1
until false
file:close()

kx=1
for ii=1,i-1,1
do
	hote = hot[ii]
	s, e = hote:find("|")
	if s ~= nil then
		name = hote:sub(1, s-1)	
		for jj=1,j-1,1
		do
			hssid = ssid[jj]
			s, e = hssid:find(name)
			if s ~= nil then
				cs, ce = hssid:find(" ")
				if cs ~= nil then
					str = hssid:sub(1, cs-1)
					hotstrength[kx] = str .. "|" .. hot[ii]	
					kx =kx + 1	
				end
			end
		end
	end
end
if hotstrength[1] ~= nil then
	table.sort(hotstrength, function(a, b) return a > b end)
	file = io.open(newlist, "w")
	k = 1
	repeat
		line = hotstrength[k]
		if line == nil then
			break
		end
		s, e = line:find("|")
		str = line:sub(s+1)
		file:write(str, "\n")
		k = k + 1
	until false
	file:close()
end