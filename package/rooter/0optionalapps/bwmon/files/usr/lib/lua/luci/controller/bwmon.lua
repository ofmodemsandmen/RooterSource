module("luci.controller.bwmon", package.seeall)

function index()
	local page
	page = entry({"admin", "nlbw", "bwmon"}, cbi("bwmon/bwmon"), "ROOter Bandwidth Monitor", 70)
	page.dependent = true
end