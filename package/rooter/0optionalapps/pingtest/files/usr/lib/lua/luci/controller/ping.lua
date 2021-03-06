-- Licensed to the public under the Apache License 2.0.

module("luci.controller.ping", package.seeall)

I18N = require "luci.i18n"
translate = I18N.translate

function index()
	local page
	local multilock = luci.model.uci.cursor():get("custom", "multiuser", "multi") or "0"
	local rootlock = luci.model.uci.cursor():get("custom", "multiuser", "root") or "0"
	if (multilock == "0") or (multilock == "1" and rootlock == "1") then
		page = entry({"admin", "modem", "ping"}, cbi("ping"), _(translate("Custom Ping Test")), 45)
		page.dependent = true
	end
end
