module("luci.controller.zerotier", package.seeall)

I18N = require "luci.i18n"
translate = I18N.translate

function index()
	local lock = luci.model.uci.cursor():get("custom", "menu", "full")
		if lock == "1" then
			page = entry({"admin", "adminmenu", "zerotier"}, template("zerotier/zerotier"), translate("Zerotier Remote Access"), 7)
			page.dependent = true
		end
	
	entry({"admin", "services", "getid"}, call("action_getid"))
	entry({"admin", "services", "sendid"}, call("action_sendid"))
	entry({"admin", "services", "get_ids"}, call("action_get_ids"))
	entry({"admin", "services", "sendenable"}, call("action_sendenable"))
	entry({"admin", "services", "get_zstatus"}, call("action_get_zstatus"))
end

function action_getid()
	local rv = {}
	id = luci.model.uci.cursor():get("zerotier", "zerotier", "join")
	rv["netid"] = id
	secret = luci.model.uci.cursor():get("zerotier", "zerotier", "secret")
	if secret == nil then
		secret = "xxxxxxxxxx"
	end
	rv["enable"] = luci.model.uci.cursor():get("zerotier", "zerotier", "enabled")
	rv["routerid"] = string.sub(secret,1,10)
	rv["password"] = luci.model.uci.cursor():get("custom", "zerotier", "password")
	rv["cust"] = luci.model.uci.cursor():get("zerotier", "zerotier", "cust")
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function action_sendid()
	local rv = {}
	local set = luci.http.formvalue("set")
	os.execute("/usr/lib/zerotier/netid.sh 1 " .. set)
	secret = luci.model.uci.cursor():get("zerotier", "zerotier", "secret")
	if secret == nil then
		secret = "xxxxxxxxxx"
	end
	rv["routerid"] = string.sub(secret,1,10)
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function action_sendenable()
	local rv = {}
	local set = luci.http.formvalue("set")
	os.execute("/usr/lib/zerotier/enable.sh 1 " .. set)
	secret = luci.model.uci.cursor():get("zerotier", "zerotier", "secret")
	if secret == nil then
		secret = "xxxxxxxxxx"
	end
	rv["routerid"] = string.sub(secret,1,10)
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function action_get_ids()
	local rv = {}
	id = luci.model.uci.cursor():get("zerotier", "zerotier", "join")
	rv["netid"] = id
	secret = luci.model.uci.cursor():get("zerotier", "zerotier", "secret")
	if secret ~= nil then
		rv["routerid"] = string.sub(secret,1,10)
	else
		rv["routerid"] = "xxxxxxxxxx"
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function action_get_zstatus()
	local rv = {}
	os.execute("/usr/lib/zerotier/status.sh")
	file = io.open("/tmp/zstatus", "r")
	rv['status'] = file:read("*line")
	rv['mac'] = file:read("*line")
	rv['ip'] = file:read("*line")
	file:close()
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

