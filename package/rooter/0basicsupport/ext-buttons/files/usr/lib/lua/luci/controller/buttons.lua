module("luci.controller.buttons", package.seeall)

local I18N = require "luci.i18n"
local translate = I18N.translate

function index()
	local page

	page = entry({"admin", "system", "buttons"}, cbi("buttons/buttons"), _(translate("Buttons")), 65)
	page.dependent = true
end
