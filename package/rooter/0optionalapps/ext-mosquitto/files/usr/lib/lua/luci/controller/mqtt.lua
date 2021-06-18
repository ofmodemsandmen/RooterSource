module("luci.controller.mqtt", package.seeall)

function index()
	local page
	page = entry({"admin", "services", "mqtt"}, template("mqtt/mqtt"), _("MQTT Remote"))
	page.dependent = true
	
	entry({"admin", "services", "get_connect_mqtt"}, call("action_get_connect_mqtt"))
	entry({"admin", "services", "connect_mqtt"}, call("action_connect_mqtt"))
	entry({"admin", "services", "get_logt_mqtt"}, call("action_get_logt_mqtt"))
	entry({"admin", "services", "mqtt_send_cmd"}, call("action_mqtt_send_cmd"))

end

function action_get_connect_mqtt()
	local rv = {}
	local set = luci.http.formvalue("set")

	line = nil
	file = io.open("/etc/mqtt_connect", "r")
	if file ~= nil then
		rv["url"] = file:read("*line")
		rv["port"] = file:read("*line")
		rv["user"] = file:read("*line")
		rv["passwd"] = file:read("*line")
		rv["tid"] = file:read("*line")
		file:close()
	else
		rv["url"] = "192.168.1.1"
		rv["port"] = "1883"
		rv["user"] = "nil"
		rv["passwd"] = "nil"
		rv["tid"] = "01"
	end
	file = io.open("/tmp/mqtt_connect_status", "r")
	if file ~= nil then
		rv["connect"] = "1"
		file:close()
	else
		rv["connect"] = "0"
	end
	
	file = io.open("/tmp/mqtt_connect_mode", "r")
	if file ~= nil then
		rv["mode"] = file:read("*line")
		file:close()
	else
			mfile = io.open("/tmp/mqtt_connect_mode", "w")
			mfile:write("1")
			mfile:close()
			rv["mode"] = "1"
	end
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function action_connect_mqtt()
	local rv = {}
	local set = luci.http.formvalue("set")
	
	os.execute("/usr/lib/mqtt/get_connect.lua \"" .. set .. "\"")
	
	file = io.open("/tmp/mqtt_connect_status", "r")
	if file ~= nil then
		rv["connect"] = file:read("*line")
		file:close()
		if rv["connect"] ~= "1" then
			os.remove("/tmp/mqtt_connect_status")
			os.remove("/tmp/mqtt_atcmd")
		end
	else
		rv["connect"] = "0"
		os.remove("/tmp/mqtt_atcmd")
	end
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function action_get_logt_mqtt()
	local file
	local rv ={}

	file = io.open("/tmp/mqtt_connect_mode", "r")
	if file ~= nil then
		mode = file:read("*line")
		file:close()
	else
		mode = "1"
	end
	
	file = io.open("/tmp/mqtt_connect_log", "r")
	if file ~= nil then
		local tmp = file:read("*all")
		rv["log"] = tmp
		file:close()
	else
		rv["log"] = "No entries in log file"
	end
	
	if mode == "0" then
		file = io.open("/tmp/mqtt_signal", "r")
		if file ~= nil then
			rv["csq"] = file:read("*line")
			rv["signal"] = file:read("*line")
			rv["rssi"] = file:read("*line")
			rv["ecio"] = file:read("*line")
			rv["rscp"] = file:read("*line")
			file:close()
		else
			rv["csq"] = " "
			rv["signal"] = " "
			rv["ecio"] = " "
			rv["rssi"] = " "
			rv["rscp"] = " "
		end
		
		file = io.open("/tmp/mqtt_info", "r")
		if file ~= nil then
			rv["ipaddr"] = file:read("*line")
			rv["model"] = file:read("*line")
			rv["connect"] = "1"
			file:close()
		else
			rv["ipaddr"] = " "
			rv["model"] = " "
			rv["connect"] = "0"
		end
		
		file = io.open("/tmp/mqtt_atcmd", "r")
		if file ~= nil then
			local tmp = file:read("*all")
			rv["atlog"] = tmp
			file:close()
		else
			rv["atlog"] = " "
		end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function action_mqtt_send_cmd()
	local rv = {}
	local set = luci.http.formvalue("set")
	
	os.remove("/tmp/mqtt_atcmd")
	local tfile = io.open("/tmp/mqtt_atcmd", "w")
	tfile:write("Waiting for a Response", "\n")
	tfile:close()
	os.execute("/usr/lib/mqtt/proccess_cmd.lua \"" .. set .. "\"")
end