module("luci.controller.speedtest", package.seeall)
function index()
	local page
	page = entry({"admin", "services", "speedtest"}, template("speedtest/speedtest"), "OpenSpeedTest", 71)
	page.dependent = true
end
