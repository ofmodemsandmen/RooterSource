module("luci.controller.gps", package.seeall)

I18N = require "luci.i18n"
translate = I18N.translate

function index()
	entry({"admin", "gps"}, firstchild(), translate("GPS"), 28).dependent=false
	entry({"admin", "gps", "gps"}, cbi("gps/gps"), translate("GPS Information"), 10)
	entry({"admin", "gps", "getcfg"}, call("action_getcfg"))
	entry({"admin", "gps", "enable"}, call("action_enable"))
	entry({"admin", "gps", "getmail"}, call("action_getmail"))
	entry({"admin", "gps", "setmail"}, call("action_setmail"))
end

function action_getmail()
	local rv ={}
	
	rv['smtp'] = luci.model.uci.cursor():get("gps", "configuration", "smtp")
	rv['euser'] = luci.model.uci.cursor():get("gps", "configuration", "euser")
	rv['epass'] = luci.model.uci.cursor():get("gps", "configuration", "epass")
	rv['password'] = luci.model.uci.cursor():get("gps", "configuration", "password")
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function action_getcfg()
	local rv ={}
	
	enable = luci.model.uci.cursor():get("gps", "configuration", "enabled")
	if enable == nil then
		enable = "0"
	end
	rv["enabled"] = enable
	
	zoom = luci.model.uci.cursor():get("gps", "configuration", "zoom")
	if zoom == nil then
		zoom = "15"
	end
	rv["zoom"] = zoom

	file = io.open("/tmp/gps", "r")
	if file ~= nil then
		rv["data"] = "1"
		file:close()
		file = io.open("/tmp/gpsdata", "r")
		if file ~= nil then
			rv["date"] = file:read("*line")
			rv["altitude"] = file:read("*line")
			rv["latitude"] = file:read("*line")
			rv["longitude"] = file:read("*line")
			rv["numsat"] = file:read("*line")
			rv["horizp"] = file:read("*line")
			rv["fix"] = file:read("*line")
			rv["heading"] = file:read("*line")
			rv["hspd"] = file:read("*line")
			rv["vspd"] = file:read("*line")
			rv["dlatitude"] = file:read("*line")
			rv["dlongitude"] = file:read("*line")
			rv["delatitude"] = file:read("*line")
			rv["delongitude"] = file:read("*line")
			rv["connected"] = file:read("*line")
			rv["mcc"] = file:read("*line")
			rv["mnc"] = file:read("*line")
			file:close()
		end
	else
		rv["data"] = "0"
		rv["connected"] = "0"
		rv["mcc"] = "0"
		rv["mnc"] = "0"
	end
	
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function action_enable()
	local set = luci.http.formvalue("set")
	os.execute("uci set gps.configuration.enabled=" .. set .. ";uci commit gps")
	os.execute("/usr/lib/gps/change.sh &")
end

function action_setmail()
	local set = luci.http.formvalue("set")
	os.execute("/usr/lib/gps/mail.sh " .. set)
end