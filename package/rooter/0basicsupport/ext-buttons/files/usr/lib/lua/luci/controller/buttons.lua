module("luci.controller.buttons", package.seeall)

function index()
	local page

	page = entry({"admin", "system", "buttons"}, cbi("buttons/buttons"), _("Buttons"), 65)
	page.dependent = true
end
