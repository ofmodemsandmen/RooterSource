local utl = require "luci.util"

local maxmodem = luci.model.uci.cursor():get("modem", "general", "max")  

m = Map("profile", translate("Modem Connection Profiles"),
	translate("Create Profiles used to provide information at connection time"))

m.on_after_commit = function(self)
	--luci.sys.call("/etc/modpwr")
end

-- 
-- Default profile
--

di = m:section(TypedSection, "default", translate("Default Profile"), translate("Used if no matching Custom Profile is found"))
di.anonymous = true
di:tab("default", translate("General"))
di:tab("advance", translate("Advanced"))
di:tab("connect", translate("Connection Monitoring"))

this_tab = "default"

ma = di:taboption(this_tab, Value, "apn", "APN :"); 
ma.rmempty = true;
ma.default = "broadband"

tt = di:taboption(this_tab, ListValue, "ttl", translate("Custom TTL Value :"))
tt:value("0", "Use Current Value")
tt:value("1", "No TTL Value")
tt:value("63", "TTL 63")
tt:value("64", "TTL 64")
tt:value("65", "TTL 65")
tt:value("66", "TTL 66")
tt:value("67", "TTL 67")
tt:value("117", "TTL 117")
tt:value("TTL-INC 1", "TTL-INC 1")
tt.default = "0"

pt = di:taboption(this_tab, ListValue, "pdptype", translate("Protocol Type :"))
pt:value("IP", "IPv4")
pt:value("IPV6", "IPv6")
pt:value("IPV4V6", "IPv4+IPv6")
pt:value("0", "Default")
pt.default = "0"

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
mtz:value("1", "Yes")
mtz.default=1

ml = di:taboption(this_tab, ListValue, "lock", translate("Roaming Allowed :"));
ml:value("0", "Yes")
ml:value("1", "No")
ml.default=1

mcc = di:taboption(this_tab, Value, "mcc", translate("Provider Country Code :"));
mcc.optional=false; 
mcc.rmempty = true;
mcc.datatype = "and(uinteger,min(1),max(999))"
mcc:depends("lock", "1")

mnc = di:taboption(this_tab, Value, "mnc", translate("Provider Network Code :"));
mnc.optional=false; 
mnc.rmempty = true;
mnc.datatype = "and(uinteger,min(1),max(999))"
mnc:depends("lock", "1")

this_taba = "advance"

mf = di:taboption(this_taba, ListValue, "ppp", translate("Force Modem to PPP Protocol :"));
mf:value("0", "No")
mf:value("1", "Yes")
mf.default=0

md = di:taboption(this_taba, Value, "delay", translate("Connection Delay in Seconds :")); 
md.optional=false; 
md.rmempty = false;
md.default = 5
md.datatype = "and(uinteger,min(5))"

nl = di:taboption(this_taba, ListValue, "nodhcp", translate("No DHCP for QMI Modems :"));
nl:value("0", "No")
nl:value("1", "Yes")
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
mlog:value("0", "No")
mlog:value("1", "Yes")
mlog.default=0

if nixio.fs.access("/etc/config/mwan3") then
	mlb = di:taboption(this_taba, ListValue, "lb", translate("Enable Load Balancing at Connection :"));
	mlb:value("0", "No")
	mlb:value("1", "Yes")
	mlb.default=0
end

mtu = di:taboption(this_taba, Value, "mtu", translate("Custom MTU :"),
		translate("Acceptable values: 1420-1500. Size for Custom MTU. This may have to be adjusted for certain ISPs"));
mtu.optional=true
mtu.rmempty = true
mtu.default = "1500"
mtu.datatype = "range(1420, 1500)"

mat = di:taboption(this_taba, ListValue, "at", translate("Enable Custom AT Startup Command at Connection :"));
mat:value("0", "No")
mat:value("1", "Yes")
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
alive:value("1", translate("Enabled"))
alive:value("2", translate("Enabled with Router Reboot"))
alive:value("3", translate("Enabled with Modem Reconnect"))
alive:value("4", translate("Enabled with Power Toggle or Modem Reconnect"))
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

dd = m:section(TypedSection, "disable", translate("Disable Automatic APN"), translate("Disable the use of automatic APN selection. All modems will use the Default Profile"))
dd.anonymous = true

enabled = dd:option(Flag, "enabled", translate("Disabled"))
enabled.default="0"
enabled.optional=false;

--
-- Custom profile
--

s = m:section(TypedSection, "custom", translate("Custom Profiles"), translate("Matches specific modem and SIM combination to a Profile"))
s.anonymous = true
s.addremove = true
s:tab("custom", translate("General"))
s:tab("cadvanced", translate("Advanced"))
s:tab("cconnect", translate("Connection Monitoring"))

this_ctab = "custom"

name = s:taboption(this_ctab, Value, "name", translate("Profile Name"))

enabled = s:taboption(this_ctab, Flag, "enabled", translate("Enabled"))
enabled.default="1"
enabled.optional=false;

select = s:taboption(this_ctab, ListValue, "select", "Select Modem by :");
select:value("0", "Modem ID")
select:value("1", "Modem IMEI")
select:value("2", "Model Name")
select:value("3", "SIM IMSI")
select:value("4", "SIM ICCID")
select.default=0

idV = s:taboption(this_ctab, Value, "vid", "Switched Vendor ID :"); 
idV.optional=false;
idV:depends("select", "0")
idV.default="xxxx"

idP = s:taboption(this_ctab, Value, "pid", "Switched Product ID :"); 
idP.optional=false;
idP:depends("select", "0") 
idP.default="xxxx"

imei = s:taboption(this_ctab, Value, "imei", "Modem IMEI Number :"); 
imei.optional=false;
imei:depends("select", "1")
imei.datatype = "uinteger"
imei.default="1234567"

model = s:taboption(this_ctab, Value, "model", "Modem Model Name contains :"); 
model.optional=false;
model:depends("select", "2")
model.default="xxxx"

imsi = s:taboption(this_ctab, Value, "imsi", "SIM IMSI Number :"); 
imsi.optional=false;
imsi:depends("select", "3")
imsi.datatype = "uinteger"
imsi.default="1234567"

iccid = s:taboption(this_ctab, Value, "iccid", "SIM ICCID Number :"); 
iccid.optional=false;
iccid:depends("select", "4")
iccid.datatype = "uinteger"
iccid.default="1234567"

select1 = s:taboption(this_ctab, ListValue, "select1", "Optional Select by :");
select1:value("0", "Modem ID")
select1:value("1", "Modem IMEI")
select1:value("2", "Model Name")
select1:value("3", "SIM IMSI")
select1:value("4", "SIM ICCID")
select1:value("10", "None")
select1.default=10

idV1 = s:taboption(this_ctab, Value, "vid1", "Switched Vendor ID :"); 
idV1.optional=false;
idV1:depends("select1", "0")
idV1.default="xxxx"

idP1 = s:taboption(this_ctab, Value, "pid1", "Switched Product ID :"); 
idP1.optional=false;
idP1:depends("select1", "0") 
idP1.default="xxxx"

imei1 = s:taboption(this_ctab, Value, "imei1", "Modem IMEI Number :"); 
imei1.optional=false;
imei1:depends("select1", "1")
imei1.datatype = "uinteger"
imei1.default="1234567"

model1 = s:taboption(this_ctab, Value, "model1", "Modem Model Name contains :"); 
model1.optional=false;
model1:depends("select1", "2")
model1.default="xxxx"

imsi1 = s:taboption(this_ctab, Value, "imsi1", "SIM IMSI Number :"); 
imsi1.optional=false;
imsi1:depends("select1", "3")
imsi1.datatype = "uinteger"
imsi1.default="1234567"

iccid1 = s:taboption(this_ctab, Value, "iccid1", "SIM ICCID Number :"); 
iccid1.optional=false;
iccid1:depends("select1", "4")
iccid1.datatype = "uinteger"
iccid1.default="1234567"

cma = s:taboption(this_ctab, Value, "apn", "APN :"); 
cma.rmempty = true;

tt = s:taboption(this_ctab, ListValue, "ttl", translate("Custom TTL Value :"))
tt:value("0", "Use Current Value")
tt:value("1", "No TTL Value")
tt:value("63", "TTL 63")
tt:value("64", "TTL 64")
tt:value("65", "TTL 65")
tt:value("66", "TTL 66")
tt:value("67", "TTL 67")
tt:value("117", "TTL 117")
tt:value("TTL-INC 1", "TTL-INC 1")
tt.default = "0"

pt = s:taboption(this_ctab, ListValue, "pdptype", "Protocol Type :")
pt:value("IP", "IPv4")
pt:value("IPv6", "IPv6")
pt:value("IPV4V6", "IPv4+IPv6")
pt:value("0", "Default")
pt.default = "0"

cmu = s:taboption(this_ctab, Value, "user", "Connection User Name :"); 
cmu.optional=false; 
cmu.rmempty = true;

cmp = s:taboption(this_ctab, Value, "passw", "Connection Password :"); 
cmp.optional=false; 
cmp.rmempty = true;
cmp.password = true

cmpi = s:taboption(this_ctab, Value, "pincode", "PIN :"); 
cmpi.optional=false; 
cmpi.rmempty = true;

cmau = s:taboption(this_ctab, ListValue, "auth", "Authentication Protocol :")
cmau:value("0", "None")
cmau:value("1", "PAP")
cmau:value("2", "CHAP")
cmau.default = "0"

cmtz = s:taboption(this_ctab, ListValue, "tzone", "Set Timezone", "Set the Timezone automatically when modem connects");
cmtz:value("0", "No")
cmtz:value("1", "Yes")
cmtz.default=1

cml = s:taboption(this_ctab, ListValue, "lock", "Roaming Allowed :");
cml:value("0", "Yes")
cml:value("1", "No")
cml.default=1

cmcc = s:taboption(this_ctab, Value, "mcc", "Provider Country Code :");
cmcc.optional=false; 
cmcc.rmempty = true;
cmcc.datatype = "and(uinteger,min(1),max(999))"
cmcc:depends("lock", "1")

cmnc = s:taboption(this_ctab, Value, "mnc", "Provider Network Code :");
cmnc.optional=false; 
cmnc.rmempty = true;
cmnc.datatype = "and(uinteger,min(1),max(999))"
cmnc:depends("lock", "1")

this_ctaba = "cadvanced"

cmf = s:taboption(this_ctaba, ListValue, "ppp", "Force Modem to PPP Protocol :");
cmf:value("0", "No")
cmf:value("1", "Yes")
cmf.default=0

cmw = s:taboption(this_ctaba, ListValue, "inter", "Modem Interface Selection :");
cmw:value("0", "Auto")
cmw:value("1", "WAN1")
cmw:value("2", "WAN2")
cmw:value("3", "OFF")
cmw.default=0

cmd = s:taboption(this_ctaba, Value, "delay", "Connection Delay in Seconds :"); 
cmd.optional=false; 
cmd.rmempty = false;
cmd.default = 5
cmd.datatype = "and(uinteger,min(5))"

cnl = s:taboption(this_ctaba, ListValue, "nodhcp", "No DHCP for QMI Modems :");
cnl:value("0", "No")
cnl:value("1", "Yes")
cnl.default=0

cmdns1 = s:taboption(this_ctaba, Value, "dns1", "Custom DNS Server1 :"); 
cmdns1.rmempty = true;
cmdns1.optional=false;
cmdns1.datatype = "ipaddr"

cmdns2 = s:taboption(this_ctaba, Value, "dns2", "Custom DNS Server2 :"); 
cmdns2.rmempty = true;
cmdns2.optional=false;
cmdns2.datatype = "ipaddr"

cmdns3 = s:taboption(this_ctaba, Value, "dns3", "Custom DNS Server3 :"); 
cmdns3.rmempty = true;
cmdns3.optional=false;
cmdns3.datatype = "ipaddr"

cmdns4 = s:taboption(this_ctaba, Value, "dns4", "Custom DNS Server4 :"); 
cmdns4.rmempty = true;
cmdns4.optional=false;
cmdns4.datatype = "ipaddr"

cmlog = s:taboption(this_ctaba, ListValue, "log", "Enable Connection Logging :");
cmlog:value("0", "No")
cmlog:value("1", "Yes")
cmlog.default=0

if nixio.fs.access("/etc/config/mwan3") then
	cmlb = s:taboption(this_ctaba, ListValue, "lb", "Enable Load Balancing at Connection :");
	cmlb:value("0", "No")
	cmlb:value("1", "Yes")
	cmlb.default=0
end

mtu = s:taboption(this_ctaba, Value, "mtu", translate("Custom MTU :"),
		translate("Acceptable values: 1420-1500. Size for Custom MTU. This may have to be adjusted for certain ISPs"));
mtu.optional=true
mtu.rmempty = true
mtu.default = "1500"
mtu.datatype = "range(1420, 1500)"

cmat = s:taboption(this_ctaba, ListValue, "at", "Enable Custom AT Startup Command at Connection :");
cmat:value("0", "No")
cmat:value("1", "Yes")
cmat.default=0

cmatc = s:taboption(this_ctaba, Value, "atc", "Custom AT Startup Command :");
cmatc.optional=false;
cmatc.rmempty = true;

--
-- Custom Connection Monitoring
--

this_ctab = "cconnect"

calive = s:taboption(this_ctab, ListValue, "alive", "Connection Monitoring Status :"); 
calive.rmempty = true;
calive:value("0", "Disabled")
calive:value("1", "Enabled")
calive:value("2", "Enabled with Router Reboot")
calive:value("3", "Enabled with Modem Reconnect")
calive:value("4", "Enabled with Power Toggle or Modem Reconnect")
calive.default=0

reliability = s:taboption(this_ctab, Value, "reliability", translate("Tracking reliability"),
		translate("Acceptable values: 1-100. This many Tracking IP addresses must respond for the link to be deemed up"))
reliability.datatype = "range(1, 100)"
reliability.default = "1"
reliability:depends("alive", "1")
reliability:depends("alive", "2")
reliability:depends("alive", "3")
reliability:depends("alive", "4")

count = s:taboption(this_ctab, ListValue, "count", translate("Ping count"))
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

interval = s:taboption(this_ctab, ListValue, "pingtime", translate("Ping interval"),
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

timeout = s:taboption(this_ctab, ListValue, "pingwait", translate("Ping timeout"))
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

packetsize = s:taboption(this_ctab, Value, "packetsize", translate("Ping packet size in bytes"),
		translate("Acceptable values: 4-56. Number of data bytes to send in ping packets. This may have to be adjusted for certain ISPs"))
	packetsize.datatype = "range(4, 56)"
	packetsize.default = "56"
	packetsize:depends("alive", "1")
	packetsize:depends("alive", "2")
	packetsize:depends("alive", "3")
	packetsize:depends("alive", "4")

down = s:taboption(this_ctab, ListValue, "down", translate("Interface down"),
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

up = s:taboption(this_ctab, ListValue, "up", translate("Interface up"),
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

cb2 = s:taboption(this_ctab, DynamicList, "trackip", translate("Tracking IP"),
		translate("This IP address will be pinged to dermine if the link is up or down."))
cb2.datatype = "ipaddr"
cb2:depends("alive", "1")
cb2:depends("alive", "2")
cb2:depends("alive", "3")
cb2:depends("alive", "4")
cb2.optional=false;
cb2.default="8.8.8.8"

return m

