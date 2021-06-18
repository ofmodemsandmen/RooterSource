#!/usr/bin/lua

local json  = require("luci.jsonc")
local uci   = require("luci.model.uci").cursor()
local mqtt = require("mosquitto")

URL = arg[1]
PORT = arg[2]
USER = arg[3]
PASS = arg[4]
TID = arg[5]

os.execute("/usr/lib/mqtt/atcmd.sh &")

printf = function(s,...)
		local ss = s:format(...)
		os.execute("/usr/lib/rooter/logprint.sh " .. ss)
end

function sleep(n)
	os.execute("sleep " .. tonumber(n))
end

function sleept(n)
	os.execute("sleep " .. tonumber(n))
end

logfile = {}
logi = 0

pubflg = 0

TOPIC = "control" .. TID
RTOPIC = "response" .. TID
client = mqtt.new()
os.remove("/tmp/mqtt_connect_status")
os.remove("/tmp/mqtt_connect_log")

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

--
-- publish and log text as a response
--
function publog(xtopic, xpayload)
	repeat
		sleept(1)
	until (pubflg == 0)
	pubflg = 1
	client:publish(xtopic, xpayload)
	sleept(1)
	logger("RESP : " .. xpayload)
	pubflg = 0
end

--
-- process "signal" command
--
function get_signal(cmdx)
	file = io.open("/tmp/status1.file", "r")
	if file ~= nil then
		rdline = file:read("*line")
		csq = file:read("*line")
		signal = file:read("*line")
		rssi = file:read("*line")
		for i=1,13,1 do
			rdline = file:read("*line")
		end
		ecio = file:read("*line")
		rscp = file:read("*line")
		for i=1,10,1 do
			rdline = file:read("*line")
		end
		temp = file:read("*line")
		file:close()
		mksignal = json.stringify({ cmd = "signal", csq = csq, signal = signal, rssi = rssi, ecio = ecio, rscp = rscp, temp = temp })
		publog(RTOPIC, mksignal)
	end
end

--
-- process "uci" command
--
function cmd_uci(cmdx)
	if cmdx.type == "get" then
		ipaddr = uci:get(cmdx.config, cmdx.section, cmdx.option)
		mkjson = json.stringify({ cmd = "uci", type = "send", config = cmdx.config, section = cmdx.section, option = cmdx.option, value = ipaddr })
		publog(RTOPIC, mkjson)		
	end
end

function pubinfo()
	ipaddr = uci:get("network", "lan", "ipaddr")
	local file = io.open("/tmp/sysinfo/model", "r")
	if file ~= nil then
		model = file:read("*line")
		file:close()
	else
		model = "?"
	end
	mkjson = json.stringify({ cmd = "info", type = "send", ipaddr = ipaddr, model = model })
	publog(RTOPIC, mkjson) 
end

function send_info(cmdz)
	pubinfo()
end

--
-- handle Run Command
--
function run_cmd(cmdx)
	os.remove("/tmp/atresult")
	fixed = string.gsub(cmdx.command, "\"", "~")
	local zfile = io.open("/tmp/mqtt_runcmd", "w")
	zfile:write(cmdx.cmdtype, "\n")
	zfile:write(fixed, "\n")
	zfile:close()
	--
	-- AT Command
	--
	if cmdx.cmdtype == "1" then
		local cflg = 0
		local result = "Error"
		repeat
			sleept(2)
			local qfile = io.open("/tmp/atresult", "r")
			if qfile ~= nil then
				result = qfile:read("*all")
				qfile:close()
				cflg = 1
			end
		until (cflg == 1)
		mkjson = json.stringify({ cmd = "atcmd", response = result })
		publog(RTOPIC, mkjson) 
	end
end

function sms_cmd(cmdx)

end

local command_tbl =
{
  ["signal"] = get_signal,
  ["uci"] = cmd_uci,
  ["info"] = send_info,
  ["runcmd"] = run_cmd,
  ["smscmd"] = sms_cmd,
}

function processr(data)
	local cmdj = json.parse(data)
	local func = command_tbl[cmdj.cmd]
	if(func) then
		func(cmdj)
	else
		mkcmd = json.stringify({ cmd = cmdj.cmd})
		publog(RTOPIC, mkcmd)
	end
end

client.ON_CONNECT = function()
        client:subscribe(TOPIC)
		pubinfo()
end

client.ON_DISCONNECT = function()
   os.remove("/tmp/mqtt_connect_status")     
end

client.ON_MESSAGE = function(mid, topic, payload)
	logger("CMD : " .. payload)
	processr(payload)
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
	repeat
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
lwill = json.stringify({ cmd = "disconnected"})
publog(RTOPIC, lwill)
sleep(5)
tfile = io.open("/tmp/mqtt_runexit", "w")
tfile:write("1")
tfile:close()
client:disconnect()
client:loop_stop()



