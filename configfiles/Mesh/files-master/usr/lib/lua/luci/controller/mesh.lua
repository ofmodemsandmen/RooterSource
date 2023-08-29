module("luci.controller.mesh", package.seeall)

I18N = require "luci.i18n"
translate = I18N.translate

function index()
	local page
	page = entry({"admin", "status", "mesh"}, template("mesh/mesh"), translate("Mesh Status"), 55)
	page.dependent = true
	
	entry({"admin", "status", "mesh_stat"}, call("action_mesh_stat"))
end

function action_mesh_stat()
	local rv = {}
	os.execute("/usr/lib/mesh/meshinfo.sh")
	file = io.open("/tmp/dmp", "r")
	if file ~= nil then
		rv['mesh'] = file:read("*line")
		file:close()
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end