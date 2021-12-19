module("luci.controller.blacklist", package.seeall)

function index()
	local page

	page = entry({"admin", "services", "blacklist"}, cbi("blacklist"), "Blacklist by Mac", 24)
	page.dependent = true
end
