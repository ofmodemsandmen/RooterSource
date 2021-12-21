--[[
ext-theme
]]--

module("luci.controller.splash", package.seeall)

function index()
	entry({"admin", "splash"}, firstchild(), "Splash Screen", 99).dependent=false
	entry({"admin", "splash", "splash"}, cbi("splashm"), _("Configuration"), 20)
end
