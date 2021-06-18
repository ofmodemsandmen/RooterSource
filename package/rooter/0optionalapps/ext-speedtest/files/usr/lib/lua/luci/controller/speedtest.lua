module("luci.controller.speedtest", package.seeall)
function index()
	local page
	page = entry({"admin", "services", "speedtest"}, template("speedtest/speedtest"), "Speed Test", 71)
	page.dependent = true
	
	entry({"admin", "services", "closeserver"}, call("action_closeserver"))
	entry({"admin", "services", "pingserver"}, call("action_pingserver"))
	entry({"admin", "services", "getspeed"}, call("action_getspeed"))
	entry({"admin", "services", "getspeeddata"}, call("action_getspeeddata"))
end

function action_closeserver()
	local rv = {}
	
	os.execute("/usr/lib/speedtest/info.sh")
	result = "/tmp/sinfo"
	file = io.open(result, "r")
	if file ~= nil then
		rv["status"] = file:read("*line")
		if rv["status"] ~= "0" then
			rv["ip"] = file:read("*line")
			rv["isp"] = file:read("*line")
			rv["city"] = file:read("*line")
			rv["prov"] = file:read("*line")
		end
		file:close()
	else
		rv["status"] = "0"
	end
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function action_pingserver()
	local rv = {}
	
	os.execute("/usr/lib/speedtest/ping.sh")
	result = "/tmp/pinfo"
	file = io.open(result, "r")
	if file ~= nil then
		rv["ping"] = file:read("*line")
		file:close()
	else
		rv["ping"] = "-"
	end
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function action_getspeed()
	local rv = {}
	
	os.execute("/usr/lib/speedtest/getspeed.sh ")

	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function action_getspeeddata()
	local rv = {}

	result = "/tmp/getspeed"
	file = io.open(result, "r")
	if file ~= nil then
		rv["dlsize"] = file:read("*line")
		rv["dlelapse"] = file:read("*line")
		rv["ulsize"] = file:read("*line")
		rv["ulelapse"] = file:read("*line")
		file:close()
	else
		rv["dlsize"] = "0"
		rv["ulsize"] = "0"
	end
	result = "/tmp/spworking"
	file = io.open(result, "r")
	if file ~= nil then
		rv["working"] = file:read("*line")
		file:close()
	else
		rv["working"] = "0"
	end
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end
