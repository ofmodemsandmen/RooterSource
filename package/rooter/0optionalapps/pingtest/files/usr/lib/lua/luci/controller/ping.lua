-- Licensed to the public under the Apache License 2.0.

module("luci.controller.ping", package.seeall)

I18N = require "luci.i18n"
translate = I18N.translate

function index()
	local page
	page = entry({"admin", "modem", "ping"}, cbi("ping"), _(translate("Custom Ping Test")), 45)
	page.dependent = true
end
