local utl = require "luci.util"
local uci  = require "luci.model.uci".cursor()

m = Map("ttl", translate("Firewall - Custom TTL Settings"),
	translate("Enable and use a custom TTL value with modems"))

m.on_after_save = function(self)
	--luci.sys.call("/usr/lib/custom/ttlx.sh &")
end

gw = m:section(TypedSection, translate("ttl"), translate("Settings"))
gw.anonymous = true

en = gw:option(Flag, "enabled", translate("Enabled :"), translate("Enable the use of custom TTL value")); 
en.default="0"
en.rmempty = false;
en.optional=false;

tt = gw:option(ListValue, "ttl", translate("Custom IPv4 TTL Value :"))
tt:value("1", translate("No TTL Value"))
tt:value("2", translate("Custom Value"))
tt:value("63", "TTL 63")
tt:value("64", "TTL 64")
tt:value("65", "TTL 65")
tt:value("66", "TTL 66")
tt:value("67", "TTL 67")
tt:value("88", "TTL 88")
tt:value("117", "TTL 117")
tt:value("128", "TTL 128")
tt.default = "1"
tt:depends("enabled", "1")

ttc = gw:option(Value, "cttl", translate("TTL Custom Value :")); 
ttc.optional=false; 
ttc.rmempty = true;
ttc.default = "65"
ttc:depends("ttl", "2")

tth = gw:option(ListValue, "hl", translate("Custom IPv6 HL Value :"))
tth:value("0", translate("Use TTL Value"))
tth:value("1", translate("No HL Value"))
tth:value("2", translate("Custom Value"))
tth:value("63", "HL 63")
tth:value("64", "HL 64")
tth:value("65", "HL 65")
tth:value("66", "HL 66")
tth:value("67", "HL 67")
tth:value("88", "HL 88")
tth:value("117", "HL 117")
tth:value("128", "HL 128")
tth.default = "0"
tth:depends("enabled", "1")

ttch = gw:option(Value, "chl", translate("HL Custom Value :")); 
ttch.optional=false; 
ttch.rmempty = true;
ttch.default = "65"
ttch:depends("hl", "2")

tnl = gw:option(ListValue, "ttloption", translate("TTL Settings"));
tnl:value("0", translate("POSTROUTING and PREROUTING (Default)"))
tnl:value("1", translate("POSTROUTING only"))
tnl:value("2", translate("POSTROUTING with ICMP passthrough (May use minimal hotspot data)"))
tnl.default=0
tnl:depends("enabled", "1")

return m