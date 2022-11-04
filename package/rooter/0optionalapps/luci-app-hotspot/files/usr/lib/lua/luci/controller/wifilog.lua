module("luci.controller.wifilog", package.seeall)

I18N = require "luci.i18n"
translate = I18N.translate

function index()
	local page
	page = entry({"admin", "hotspot", "wifilog"}, template("wifilog/wifilog"), _(translate("Hotspot Logging")), 61)
	page.dependent = true

	entry({"admin", "status", "wifilog"}, call("action_wifilog"))
end

function action_wifilog()
	local file
	local rv ={}

	file = io.open("/tmp/wifilog.log", "r")
	if file ~= nil then
		local tmp = file:read("*all")
		rv["log"] = tmp
		file:close()
	else
		rv["log"] = translate("No entries in log file")
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end