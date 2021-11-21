module("luci.controller.bwmon", package.seeall) 

function index()
	local page
	entry({"admin", "nlbw"}, firstchild(), "Bandwidth Monitor", 80).dependent=false
	page = entry({"admin", "nlbw", "bwmon"}, template("bwmon/bwmon"), "ROOter Bandwidth Monitor", 70)
	page.dependent = true
	
	entry({"admin", "nlbw", "check_bw"}, call("action_check_bw"))
	entry({"admin", "nlbw", "change_bw"}, call("action_change_bw"))
	entry({"admin", "nlbw", "change_roll"}, call("action_change_roll"))
	entry({"admin", "nlbw", "change_enable"}, call("action_change_enable"))
end

function action_check_bw()
	local rv = {}
	local maclist = {}
	
	file = io.open("/tmp/bwdata", "r")
	if file ~= nil then
		rv['days'] = file:read("*line")
		if rv['days'] ~= "0" then
			rv['total'] = file:read("*line")
			rv['ctotal'] = file:read("*line")
			rv['totaldown'] = file:read("*line")
			rv['ctotaldown'] = file:read("*line")
			rv['totalup'] = file:read("*line")
			rv['ctotalup'] = file:read("*line")
			rv['ptotal'] = file:read("*line")
			rv['cptotal'] = file:read("*line")
			rv['atotal'] = file:read("*line")
			rv['catotal'] = file:read("*line")
			rv['password'] = file:read("*line")
			j = file:read("*line")
			if j == nil then
				j = 0
			end
			rv['macsize'] = j
			if j ~=0 then
				for i=0, j-1 do
					maclist[i] = file:read("*line")
				end
				rv['maclist'] = maclist
			end
		end
		file:close()
	else
		rv['days'] = 0
	end
	rv['lock']  = luci.model.uci.cursor():get("custom", "bwallocate", "lock")
	rv['rollover'] = luci.model.uci.cursor():get("custom", "bwallocate", "rollover")
	rv['enabled'] = luci.model.uci.cursor():get("custom", "bwallocate", "enabled")
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function action_change_bw()
	local set = luci.http.formvalue("set")
	os.execute("/usr/lib/bwmon/allocate.sh " .. set)
	
end

function action_change_roll()
	local set = luci.http.formvalue("set")
	os.execute("/usr/lib/bwmon/rollover.sh " .. set)
	
end

function action_change_enable()
	local set = luci.http.formvalue("set")
	os.execute("uci set custom.bwallocate.enabled=" .. set .. "; uci commit custom")
	
end