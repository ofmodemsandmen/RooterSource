-- Licensed to the public under the Apache License 2.0.

module("luci.controller.ksmbd", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/ksmbd") then
		return
	end

	entry({"admin", "services", "ksmbd"}, view("ksmbd"), _("KSMBD Network Shares"), 34).dependent = true
end 
