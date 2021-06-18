#!/usr/bin/lua

local json  = require("luci.jsonc")
local uci   = require("luci.model.uci").cursor()
local mqtt = require("mosquitto")

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

printf = function(s,...)
		local ss = s:format(...)
		os.execute("/usr/lib/rooter/logprint.sh " .. ss)
end

payload = arg[1]

conflg = string.sub(payload, 1, 1)
commd = trim(payload:sub(2))

printf("AT Command %s\n", commd)

mkcmd = json.stringify({ cmd = "runcmd", cmdtype = conflg, command = commd})

local xfile = io.open("/tmp/mqtt_command", "w")
xfile:write(mkcmd, "\n")
xfile:close()
