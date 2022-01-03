module("luci.controller.bwallocate", package.seeall)
function index()
	local lock = luci.model.uci.cursor():get("custom", "menu", "full")
	if lock == "1" then
		local lock1 = luci.model.uci.cursor():get("custom", "bwallocate", "lock")
		if lock1 == "1" then
			entry({"admin", "adminmenu", "bwmenu"}, cbi("fullmenu/bwmenu"), "---Bandwidth Allocation", 6)
		end
	end
end