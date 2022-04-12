-- Copyright 2016-2017 Dan Luedtke <mail@danrl.com>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.wireguard", package.seeall)
local I18N = require "luci.i18n"
local translate = I18N.translate

function index()
  entry({"admin", "vpn", "wireguards"}, template("wireguard/wireguard"), _(translate("--WireGuard Status")), 70)
  entry({"admin", "vpn", "wireguard"}, cbi("wireguard"), _("Wireguard"), 63)
  entry( {"admin", "vpn", "wireguard", "client"},    cbi("wireguard-client"),    nil ).leaf = true
  entry( {"admin", "vpn", "wireguard", "server"},    cbi("wireguard-server"),    nil ).leaf = true
  
  entry( {"admin", "vpn", "wireguard", "wupload"},   call("conf_upload"))
  entry( {"admin", "vpn", "generateconf"},   call("conf_gen"))
end

function conf_upload()
	local fs     = require("nixio.fs")
	local http   = require("luci.http")
	local util   = require("luci.util")
	local uci    = require("luci.model.uci").cursor()
	local upload = http.formvalue("ovpn_file")
	local name   = http.formvalue("instance_name2")
	local file   = "/etc/openvpn/" ..name.. ".conf"

	if name and upload then
		local fp

		http.setfilehandler(
			function(meta, chunk, eof)
				local data = util.trim(chunk:gsub("\r\n", "\n")) .. "\n"
				data = util.trim(data:gsub("[\128-\255]", ""))

				if not fp and meta and meta.name == "ovpn_file" then
					fp = io.open(file, "w")
				end
				if fp and data then
					fp:write(data)
				end
				if fp and eof then
					fp:close()
				end
			end
		)

		if fs.access(file) then
			os.execute("/usr/lib/wireguard/conf.sh " .. name .. " " .. file)
		end
	end
	http.redirect(luci.dispatcher.build_url('admin/vpn/wireguard'))
end

function conf_gen()
	os.execute("/usr/lib/wireguard/create.sh")
end