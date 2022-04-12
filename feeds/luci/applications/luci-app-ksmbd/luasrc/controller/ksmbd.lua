-- Licensed to the public under the Apache License 2.0.

module("luci.controller.ksmbd", package.seeall)

I18N = require "luci.i18n"
translate = I18N.translate

function index()
	if not nixio.fs.access("/etc/config/ksmbd") then
		return
	end

	entry({"admin", "services", "ksmbd"}, view("ksmbd"), _(translate("KSMBD Network Shares")), 34).dependent = true
end 
