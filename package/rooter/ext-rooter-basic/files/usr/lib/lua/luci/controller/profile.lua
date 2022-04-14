module("luci.controller.profile", package.seeall)
function index()
	entry({"admin", "profile", "savecfg"}, call("action_savecfg"))
	entry({"admin", "profile", "loadcfg"}, call("action_loadcfg"))
end

function action_savecfg()
	os.execute('/usr/lib/profile/savecfg.sh')
end

function action_loadcfg()
	local set = luci.http.formvalue("set")
	os.execute('/usr/lib/profile/loadcfg.sh "' .. set .. '"')
end