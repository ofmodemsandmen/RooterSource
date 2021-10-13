-- Licensed to the public under the Apache License 2.0.

module("luci.controller.domain", package.seeall)

function index()
	local page
	page = entry({"admin", "network", "domain"}, cbi("domainfltr"), _("Domain Filter"), 65)
	page.dependent = true
end
