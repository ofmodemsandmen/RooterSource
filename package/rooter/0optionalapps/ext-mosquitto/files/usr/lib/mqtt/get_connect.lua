#!/usr/bin/lua

local json  = require("luci.jsonc")
local uci   = require("luci.model.uci").cursor()
local mqtt = require("mosquitto")
local url, port, user, password, tid

printf = function(s,...)
		local ss = s:format(...)
		os.execute("/usr/lib/rooter/logprint.sh " .. ss)
end

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function run_remote()
	os.remove("/tmp/mqtt_connect_status")
	os.execute("/usr/lib/mqtt/remote.lua " .. url .. " " .. port .. " " .. user .. " " .. password .. " " .. tid .. " &")
	repeat
		tfile = io.open("/tmp/mqtt_connect_status", "r")
		sflg = 0
		if tfile ~= nil then
			sflg = 1
			tfile:close()
		end
	until ( sflg == 1)
end

function run_control()
	os.remove("/tmp/mqtt_connect_status")
	os.execute("/usr/lib/mqtt/control.lua " .. url .. " " .. port .. " " .. user .. " " .. password .. " " .. tid .. " &")
	repeat
		tfile = io.open("/tmp/mqtt_connect_status", "r")
		sflg = 0
		if tfile ~= nil then
			sflg = 1
			tfile:close()
		end
	until ( sflg == 1)
end

payload = arg[1]

conflg = string.sub(payload, 1, 1)
mode = string.sub(payload, 2, 2)

mfile = io.open("/tmp/mqtt_connect_mode", "w")
mfile:write(mode)
mfile:close()
	
if conflg == "1" then
	s, e = payload:find("~", 3)
	if s ~= nil then
		url = payload:sub(3, e-1)
		cs, ce = payload:find("~", e+1)
		if cs ~= nil then
			port = payload:sub(e+1, ce-1)
			s, e = payload:find("~", ce+1)
			if s ~= nil then
				user = payload:sub(ce+1, e-1)
				cs, ce = payload:find("~", e+1)
				if cs ~= nil then
					password = payload:sub(e+1, ce-1)
					s, e = payload:find("~", ce+1)
					if s ~= nil then
						tid = payload:sub(ce+1, e-1)
						file = io.open("/etc/mqtt_connect", "w")
						if file ~= nil then
							file:write(url, "\n")
							file:write(port, "\n")
							file:write(user, "\n")
							file:write(password, "\n")
							file:write(tid, "\n")
							file:close()
						end
						if mode == "1" then
							run_remote()
						else
							run_control()
						end
					end
				end
			end
		end
	end
 else
	os.remove("/tmp/mqtt_connect_status")
end