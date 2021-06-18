-- Licensed to the public under the Apache License 2.0.

module("luci.controller.ping", package.seeall)

function index()
	local page
	page = entry({"admin", "modem", "ping"}, cbi("ping"), _("Custom Ping Test"), 45)
	page.dependent = true
end
