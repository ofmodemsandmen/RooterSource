module("luci.controller.zerotier", package.seeall)
function index()
	local fs = require "nixio.fs"
	if fs.stat("/etc/config/zerotier") then
		local page
		page = entry({"admin", "services", "zerotier"}, template("zerotier/zerotier"), "Zerotier", 71)
		page.dependent = true
	end
	
	entry({"admin", "services", "getid"}, call("action_getid"))
	entry({"admin", "services", "sendid"}, call("action_sendid"))
	entry({"admin", "services", "get_ids"}, call("action_get_ids"))
end

function action_getid()
	local rv = {}
	id = luci.model.uci.cursor():get("zerotier", "zerotier1", "join")
	rv["netid"] = id
	secret = luci.model.uci.cursor():get("zerotier", "zerotier1", "secret")
	rv["routerid"] = string.sub(secret,1,10)
	file = io.open("/etc/zlock", "r")
	if file == nil then
		rv["password"] = "password"
	else
		rv["password"] = file:read("*line")
		file:close()
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function action_sendid()
	local set = luci.http.formvalue("set")
	os.execute("/usr/lib/zerotier/netid.sh 1 " .. set)
end

function action_get_ids()
	local rv = {}
	id = luci.model.uci.cursor():get("zerotier", "zerotier1", "join")
	rv["netid"] = id
	secret = luci.model.uci.cursor():get("zerotier", "zerotier1", "secret")
	rv["routerid"] = string.sub(secret,1,10)
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end