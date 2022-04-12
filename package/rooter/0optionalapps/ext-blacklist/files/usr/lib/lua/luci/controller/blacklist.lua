module("luci.controller.blacklist", package.seeall)
local I18N = require "luci.i18n"
local translate = I18N.translate

function index()
	local page
	local lock = luci.model.uci.cursor():get("custom", "menu", "full")
	if lock == "1" then
		page = entry({"admin", "adminmenu", "blacklist"}, cbi("blacklist"), translate("---Blacklist by Mac"), 10)
		page.dependent = true
	end
end
