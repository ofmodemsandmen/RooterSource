local utl = require "luci.util"
local uci = require "luci.model.uci".cursor()
local sys   = require "luci.sys"
local fs = require "nixio.fs" 

local maxmodem = luci.model.uci.cursor():get("modem", "general", "max")  
local profsave = luci.model.uci.cursor():get("custom", "profile", "save")  
if profsave == nil then
	profsave ="0"
end
local multilock = luci.model.uci.cursor():get("custom", "multiuser", "multi") or "0"
local rootlock = luci.model.uci.cursor():get("custom", "multiuser", "root") or "0"

m = Map("profile", translate("Modem Connection Profiles"),
	translate("Create Profiles used to provide information at connection time"))

m.on_after_commit = function(self)
	if profsave == "1" then
		--luci.sys.call("/usr/lib/profile/restart.sh &")
	end
end

if profsave == "1" then
	m:section(SimpleSection).template = "rooter/country"
	ds = m:section(TypedSection, "simpin", translate("Default SIM Pin"), translate("Used if no SIM Pin value in Profile"))
	ds.anonymous = true
	
	ms = ds:option(Value, "pin", translate("PIN :")); 
	ms.rmempty = true;
	ms.default = ""
end


-- 
-- Default profile
--

di = m:section(TypedSection, "default", translate("Default Profile"), translate("Used if no matching Custom Profile is found"))
di.anonymous = true
di:tab("default", translate("General"))
di:tab("advance", translate("Advanced"))
di:tab("connect", translate("Connection Monitoring"))
if (multilock == "0") or (multilock == "1" and rootlock == "1") then
	di:tab("bwidth", translate("Bandwidth Reporting"))
end

this_tab = "default"

ma = di:taboption(this_tab, Value, "apn", "APN :"); 
ma.rmempty = true;
ma.default = ""

tt = di:taboption(this_tab, ListValue, "ttl", translate("Custom TTL Value :"))
tt:value("0", translate("Use Current Value"))
tt:value("1", translate("No TTL Value"))
tt:value("63", "TTL 63")
tt:value("64", "TTL 64")
tt:value("65", "TTL 65")
tt:value("66", "TTL 66")
tt:value("67", "TTL 67")
tt:value("117", "TTL 117")
tt:value("TTL-INC 1", "TTL-INC 1")
tt.default = "0"

tnl = di:taboption(this_tab, ListValue, "ttloption", translate("TTL Settings"));
tnl:value("0", translate("POSTROUTING and PREROUTING (Default)"))
tnl:value("1", translate("POSTROUTING only"))
tnl:value("2", translate("POSTROUTING with ICMP passthrough (May use minimal hotspot data)"))
tnl.default=0

ynl = di:taboption(this_tab, ListValue, "hostless", translate("Adjust TTL for Hostless Modem"));
ynl:value("0", "No")
ynl:value("1", translate("Yes"))
ynl.default=0

pt = di:taboption(this_tab, ListValue, "pdptype", translate("Protocol Type :"))
pt:value("IP", "IPv4")
pt:value("IPV6", "IPv6")
pt:value("IPV4V6", "IPv4+IPv6")
pt:value("0", "Default")
pt.default = "0"

cmcc = di:taboption(this_tab, Value, "context", translate("PDP Context for APN :"));
cmcc.optional=false; 
cmcc.rmempty = true;
cmcc.datatype = "and(uinteger,min(1),max(10))"
cmcc.default = "1"

mu = di:taboption(this_tab, Value, "user", translate("Connection User Name :")); 
mu.optional=false; 
mu.rmempty = true;

mp = di:taboption(this_tab, Value, "passw", translate("Connection Password :")); 
mp.optional=false; 
mp.rmempty = true;
mp.password = true

mpi = di:taboption(this_tab, Value, "pincode", translate("PIN :")); 
mpi.optional=false; 
mpi.rmempty = true;

mau = di:taboption(this_tab, ListValue, "auth", translate("Authentication Protocol :"))
mau:value("0", "None")
mau:value("1", "PAP")
mau:value("2", "CHAP")
mau.default = "0"

mtz = di:taboption(this_tab, ListValue, "tzone", translate("Auto Set Timezone"), translate("Set the Timezone automatically when modem connects"));
mtz:value("0", "No")
mtz:value("1", translate("Yes"))
mtz.default=1

if profsave == "1" then
	ml = di:taboption(this_tab, ListValue, "lock", translate("Allow Roaming :"));
	ml:value("0", translate("Yes"))
	ml:value("1", translate("No - Hard Lock"))
	ml:value("2", translate("Yes - Soft Lock"))
	ml.default=0
else
	ml = di:taboption(this_tab, ListValue, "lock", translate("Lock to Provider :"));
	ml:value("0", translate("No"))
	ml:value("1", translate("Hard"))
	ml:value("2", translate("Soft"))
	ml.default=0
end
mcc = di:taboption(this_tab, Value, "mcc", translate("Provider Country Code :"));
mcc.optional=false; 
mcc.rmempty = true;
mcc.datatype = "and(uinteger,min(1),max(999))"
mcc:depends("lock", "1")
mcc:depends("lock", "2")

mnc = di:taboption(this_tab, Value, "mnc", translate("Provider Network Code :"));
mnc.optional=false; 
mnc.rmempty = true;
mnc.datatype = "and(uinteger,min(1),max(999))"
mnc:depends("lock", "1")
mnc:depends("lock", "2")

this_taba = "advance"

mf = di:taboption(this_taba, ListValue, "ppp", translate("Force Modem to PPP Protocol :"));
mf:value("0", translate("No"))
mf:value("1", translate("Yes"))
mf.default=0

md = di:taboption(this_taba, Value, "delay", translate("Connection Delay in Seconds :")); 
md.optional=false; 
md.rmempty = false;
md.default = 5
md.datatype = "and(uinteger,min(5))"

nl = di:taboption(this_taba, ListValue, "nodhcp", translate("No DHCP for QMI Modems :"));
nl:value("0", translate("No"))
nl:value("1", translate("Yes"))
nl.default=0

mdns1 = di:taboption(this_taba, Value, "dns1", translate("Custom DNS Server1 :")); 
mdns1.rmempty = true;
mdns1.optional=false;
mdns1.datatype = "ipaddr"

mdns2 = di:taboption(this_taba, Value, "dns2", translate("Custom DNS Server2 :")); 
mdns2.rmempty = true;
mdns2.optional=false;
mdns2.datatype = "ipaddr"

mdns3 = di:taboption(this_taba, Value, "dns3", translate("Custom DNS Server3 :")); 
mdns3.rmempty = true;
mdns3.optional=false;
mdns3.datatype = "ipaddr"

mdns4 = di:taboption(this_taba, Value, "dns4", translate("Custom DNS Server4 :")); 
mdns4.rmempty = true;
mdns4.optional=false;
mdns4.datatype = "ipaddr"


mlog = di:taboption(this_taba, ListValue, "log", translate("Enable Connection Logging :"));
mlog:value("0", translate("No"))
mlog:value("1", translate("Yes"))
mlog.default=0

if nixio.fs.access("/etc/config/mwan3") then
	mlb = di:taboption(this_taba, ListValue, "lb", translate("Enable Load Balancing at Connection :"));
	mlb:value("0", translate("No"))
	mlb:value("1", translate("Yes"))
	mlb.default=1
end

mtu = di:taboption(this_taba, Value, "mtu", translate("Custom MTU :"),
		translate("Acceptable values: 1420-1500. Size for Custom MTU. This may have to be adjusted for certain ISPs"));
mtu.optional=true
mtu.rmempty = true
mtu.default = "1500"
mtu.datatype = "range(1420, 1500)"

mat = di:taboption(this_taba, ListValue, "at", translate("Enable Custom AT Startup Command at Connection :"));
mat:value("0", translate("No"))
mat:value("1", translate("Yes"))
mat.default=0

matc = di:taboption(this_taba, Value, "atc", translate("Custom AT Startup Command :"));
matc.optional=false;
matc.rmempty = true;

--
-- Default Connection Monitoring
--

this_tab = "connect"

alive = di:taboption(this_tab, ListValue, "alive", translate("Connection Monitoring Status :")); 
alive.rmempty = true;
alive:value("0", translate("Disabled"))
alive:value("2", translate("Enabled with Router Reboot"))
alive:value("3", translate("Enabled with Modem Restart"))
alive.default=0

reliability = di:taboption(this_tab, Value, "reliability", translate("Tracking reliability"),
		translate("Acceptable values: 1-100. This many Tracking IP addresses must respond for the link to be deemed up"))
reliability.datatype = "range(1, 100)"
reliability.default = "1"
reliability:depends("alive", "1")
reliability:depends("alive", "2")
reliability:depends("alive", "3")
reliability:depends("alive", "4")

count = di:taboption(this_tab, ListValue, "count", translate("Ping count"))
count.default = "1"
count:value("1")
count:value("2")
count:value("3")
count:value("4")
count:value("5")
count:depends("alive", "1")
count:depends("alive", "2")
count:depends("alive", "3")
count:depends("alive", "4")

interval = di:taboption(this_tab, ListValue, "pingtime", translate("Ping interval"),
		translate("Amount of time between tracking tests"))
interval.default = "10"
interval:value("5", translate("5 seconds"))
interval:value("10", translate("10 seconds"))
interval:value("20", translate("20 seconds"))
interval:value("30", translate("30 seconds"))
interval:value("60", translate("1 minute"))
interval:value("300", translate("5 minutes"))
interval:value("600", translate("10 minutes"))
interval:value("900", translate("15 minutes"))
interval:value("1800", translate("30 minutes"))
interval:value("3600", translate("1 hour"))
interval:depends("alive", "1")
interval:depends("alive", "2")
interval:depends("alive", "3")
interval:depends("alive", "4")

timeout = di:taboption(this_tab, ListValue, "pingwait", translate("Ping timeout"))
timeout.default = "2"
timeout:value("1", translate("1 second"))
timeout:value("2", translate("2 seconds"))
timeout:value("3", translate("3 seconds"))
timeout:value("4", translate("4 seconds"))
timeout:value("5", translate("5 seconds"))
timeout:value("6", translate("6 seconds"))
timeout:value("7", translate("7 seconds"))
timeout:value("8", translate("8 seconds"))
timeout:value("9", translate("9 seconds"))
timeout:value("10", translate("10 seconds"))
timeout:depends("alive", "1")
timeout:depends("alive", "2")
timeout:depends("alive", "3")
timeout:depends("alive", "4")

packetsize = di:taboption(this_tab, Value, "packetsize", translate("Ping packet size in bytes"),
		translate("Acceptable values: 4-56. Number of data bytes to send in ping packets. This may have to be adjusted for certain ISPs"))
	packetsize.datatype = "range(4, 56)"
	packetsize.default = "56"
	packetsize:depends("alive", "1")
	packetsize:depends("alive", "2")
	packetsize:depends("alive", "3")
	packetsize:depends("alive", "4")

down = di:taboption(this_tab, ListValue, "down", translate("Interface down"),
		translate("Interface will be deemed down after this many failed ping tests"))
down.default = "3"
down:value("1")
down:value("2")
down:value("3")
down:value("4")
down:value("5")
down:value("6")
down:value("7")
down:value("8")
down:value("9")
down:value("10")
down:depends("alive", "1")
down:depends("alive", "2")
down:depends("alive", "3")
down:depends("alive", "4")

up = di:taboption(this_tab, ListValue, "up", translate("Interface up"),
		translate("Downed interface will be deemed up after this many successful ping tests"))
up.default = "3"
up:value("1")
up:value("2")
up:value("3")
up:value("4")
up:value("5")
up:value("6")
up:value("7")
up:value("8")
up:value("9")
up:value("10")
up:depends("alive", "1")
up:depends("alive", "2")
up:depends("alive", "3")
up:depends("alive", "4")

cb2 = di:taboption(this_tab, DynamicList, "trackip", translate("Tracking IP"),
		translate("This IP address will be pinged to dermine if the link is up or down."))
cb2.datatype = "ipaddr"
cb2:depends("alive", "1")
cb2:depends("alive", "2")
cb2:depends("alive", "3")
cb2:depends("alive", "4")
cb2.optional=false;
cb2.default="8.8.8.8"

return m

