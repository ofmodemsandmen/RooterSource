module("luci.controller.multimodem", package.seeall)
local http = require("luci.http")

I18N = require "luci.i18n"
translate = I18N.translate

function index()
	entry({"admin", "modem", "multimodem"}, template("rooter/multimodem"), _(translate("Multiple Modems")), 49)
	
	entry({"admin", "modem", "maxmodem"}, call("action_maxmodem"))
end

function action_maxmodem()
	local set = luci.http.formvalue("set")
	os.execute("/usr/lib/rooter/luci/maxmodem.sh " .. set)
end