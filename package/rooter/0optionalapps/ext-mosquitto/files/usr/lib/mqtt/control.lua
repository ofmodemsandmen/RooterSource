#!/usr/bin/lua

local json  = require("luci.jsonc")
local uci   = require("luci.model.uci").cursor()
local mqtt = require("mosquitto")

URL = arg[1]
PORT = arg[2]
USER = arg[3]
PASS = arg[4]
TID = arg[5]

logfile = {}
logi = 0
remote_connected = 0

printf = function(s,...)
		local ss = s:format(...)
		os.execute("/usr/lib/rooter/logprint.sh " .. ss)
end

function sleep(n)
  os.execute("sleep " .. tonumber(n))
end

TOPIC = "control" .. TID
RTOPIC = "response" .. TID
client = mqtt.new()
os.remove("/tmp/mqtt_connect_status")
os.remove("/tmp/mqtt_connect_log")
os.remove("/tmp/mqtt_info")
os.remove("/tmp/mqtt_signal")

--
-- process signal data
--
function send_signal(cmdx)
	local xfile = io.open("/tmp/mqtt_signal", "w")
	xfile:write(cmdx.csq, "\n")
	xfile:write(cmdx.signal, "\n")
	xfile:write(cmdx.rssi, "\n")
	if cmdx.ecio ~= "-" then
		xfile:write(cmdx.ecio .. " dB", "\n")
	else
		xfile:write(cmdx.ecio, "\n")
	end
	if cmdx.rscp ~= "-" then
		xfile:write(cmdx.rscp .. " dBm", "\n")
	else
		xfile:write(cmdx.rscp, "\n")
	end
	xfile:close()
end

--
-- process remote device info
--
function get_info(cmdx)
	local xfile = io.open("/tmp/mqtt_info", "w")
	xfile:write(cmdx.ipaddr, "\n")
	xfile:write(cmdx.model, "\n")
	xfile:close()
	remote_connected = 1
end
--
-- log text to rotating log file
--
function logger(text)
	local maxlog = 15
	local tfile
	logfile[logi] = text
	logi = logi + 1
	
	if logi > maxlog then
		for k=1,logi-1 do
			logfile[k-1] = logfile[k]
		end
		logi = maxlog
	end
	tfile = io.open("/tmp/mqtt_connect_log", "w")
	for k=0,logi-1 do
		tfile:write(logfile[k], "\n")
	end
	tfile:close()
end

function got_discon(cmdx)
	os.remove("/tmp/mqtt_info")
	os.remove("/tmp/mqtt_signal")
	remote_connected = 0
end

function got_atcmd(cmdx)
	local tfile = io.open("/tmp/mqtt_atcmd", "w")
	tfile:write(cmdx.response, "\n")
	tfile:close()
end

local command_tbl =
{
  ["signal"] = send_signal,
  ["info"] = get_info,
  ["disconnected"] = got_discon,
  ["atcmd"] = got_atcmd,
}

function process(data)
	local cmdj = json.parse(data)
	local func = command_tbl[cmdj.cmd]
	if(func) then
		func(cmdj)
	else
		mkcmd = json.stringify({ cmd = cmdj.cmd})
		logger("RESP : " .. mkcmd)
	end
end

client.ON_CONNECT = function()
        client:subscribe(RTOPIC)
		client:publish(TOPIC, '{ "cmd" : "info" }')
		start_time = os.time()
end

client.ON_MESSAGE = function(mid, topic, payload)
	process(payload)
end

local tfile
	
broker = URL
if USER ~= nil then
	client:login_set (USER, PASS)
end
err = client:connect(broker, PORT)
sleep(1)
if err then
	sleep(1)
	tfile = io.open("/tmp/mqtt_connect_status", "w")
	tfile:write("1")
	tfile:close()
	client:loop_start()
	sleep(1)
	if remote_connected == 1 then
		client:publish(TOPIC, '{ "cmd" : "signal" }')
		sleep(1)
	end
	repeat
		if remote_connected == 1 then
			diff = os.difftime(os.time(), start_time)
			if diff > 10 then
				start_time = os.time()
				client:publish(TOPIC, '{ "cmd" : "signal" }')
				sleep(1)
			end
	-- check for waiting command
			tfile = io.open("/tmp/mqtt_command", "r")
			if tfile ~= nil then
				cmdd = tfile:read("*line")
				tfile:close()
				os.remove("/tmp/mqtt_command")
				client:publish(TOPIC, cmdd)
				logger(cmdd)
			end
			sleep(1)
		end
		tfile = io.open("/tmp/mqtt_connect_status", "r")
		sflg = 0
		if tfile ~= nil then
			sflg = 1
			tfile:close()
		end
		sleep(1)
	until ( sflg == 0)
else
	tfile = io.open("/tmp/mqtt_connect_status", "w")
	tfile:write("2")
	tfile:close()
end
os.remove("/tmp/mqtt_info")
os.remove("/tmp/mqtt_signal")
client:disconnect()
client:loop_stop()
