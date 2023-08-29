module("luci.controller.wifi", package.seeall)

I18N = require "luci.i18n"
translate = I18N.translate

function index()
	local page
		page = entry({"admin", "network", "bwifi"}, template("wifi/bwifi"), _(translate("Wireless Overview")), 20)
		page.dependent = true
	
	entry({"admin", "network", "wifidata"}, call("action_wifidata"))
	entry({"admin", "network", "setwifi"}, call("action_setwifi"))
end

function action_wifidata()
	local rv = {}
	os.execute("/usr/lib/wifi/getdata.sh")
	local file = io.open("/tmp/wifisettings", "r")
	
	rv['dual'] = file:read("*line")
	rv['tworadio'] = file:read("*line")
	rv['twodisabled'] = file:read("*line")
	rv['twonoscan'] = file:read("*line")
	rv['twossid'] = file:read("*line")
	rv['twokey'] = file:read("*line")
	rv['twoencryption'] = file:read("*line")
	rv['twomode'] = file:read("*line")
	rv['twochannel'] = file:read("*line")
	rv['twoclist'] = file:read("*line")
	rv['twohtmode'] = file:read("*line")
	rv['twohmode'] = file:read("*line")
	rv['twocurrtx'] = file:read("*line")
	rv['twotxlist'] = file:read("*line")
	rv['twotxcnt'] = file:read("*line")
	rv['twocountry'] = file:read("*line")
	if rv['dual'] == "1" then
		rv['fiveradio'] = file:read("*line")
		rv['fivedisabled'] = file:read("*line")
		rv['fivenoscan'] = file:read("*line")
		rv['fivessid'] = file:read("*line")
		rv['fivekey'] = file:read("*line")
		rv['fiveencryption'] = file:read("*line")
		rv['fivemode'] = file:read("*line")
		rv['fivechannel'] = file:read("*line")
		rv['fiveclist'] = file:read("*line")
		rv['fivehtmode'] = file:read("*line")
		rv['fivehmode'] = file:read("*line")
		rv['fivecurrtx'] = file:read("*line")
		rv['fivetxlist'] = file:read("*line")
		rv['fivetxcnt'] = file:read("*line")
		rv['fivecountry'] = file:read("*line")
	end
	
	file:close()
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function action_setwifi()
	local set = luci.http.formvalue("set")
	os.execute("/usr/lib/wifi/setwifi.sh \"" .. set .. "\"")
end