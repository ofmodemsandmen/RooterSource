module("luci.controller.yamon3", package.seeall)

function index()
	local page

	page = entry({"admin", "nlbw", "yamon3"}, cbi("yamon3"), _("YAMon3 Bandwidth Monitor"), 64) 
	page.dependent = true
end
