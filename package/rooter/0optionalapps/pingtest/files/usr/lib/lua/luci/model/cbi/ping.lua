local utl = require "luci.util"

local sys   = require "luci.sys"
local zones = require "luci.sys.zoneinfo"
local fs    = require "nixio.fs"
local conf  = require "luci.config"

m = Map("ping", translate("Custom Ping Test"), translate("Enable/Disable Custom Ping Test"))

d = m:section(TypedSection, "ping", " ")
d.anonymous = true

c1 = d:option(ListValue, "enable", translate("Ping Test Status : "), translate("Ping every 20 seconds and, if it fails, restart modem or reboot router"));
c1:value("0", translate("Disabled"))
c1:value("1", translate("Enabled"))
c1.default=0

interval = d:option(Value, "interval", translate("Test Interval :"), translate("Number of seconds between testing the connection. Range is 20 to 120 secs.")); 
interval.rmempty = true;
interval.optional=false;
interval.datatype = 'range(20,120)';
interval.default="20";

type = d:option(ListValue, "type", translate("Test Type :"), translate("Type of test - Page Retrieval or Ping"));
type:value("0", translate("Ping"))
type:value("1", translate("Page Retrieval"))
type.default=1

d1 = d:option(ListValue, "delay", translate("Reconnection Delay"),translate("Delay in seconds after restarting modem before checking for connection"));
d1:value("40", "40 seconds")
d1:value("45", "45 seconds")
d1:value("50", "50 seconds")
d1:value("55", "55 seconds")
d1:value("60", "60 seconds")
d1:value("70", "70 seconds")
d1:value("80", "80 seconds")
d1:value("90", "90 seconds")
d1:value("100", "100 seconds")
d1:value("120", "120 seconds")
d1.default=40

d1x = d:option(ListValue, "timeout", translate("Ping Timeout"),translate("Seconds to wait for a ping response. Increase if under heavy load"));
d1x:value("1", "1 second")
d1x:value("2", "2 seconds")
d1x:value("3", "3 seconds")
d1x:value("5", "5 seconds")
d1x:value("10", "10 seconds")
d1x:value("15", "15 seconds")
d1x:value("20", "20 seconds")
d1x:value("25", "25 seconds")
d1x.default=5

ipv41 = d:option(Value, "ipv41", translate("IPv4 Server :"), translate("First IPv4 server to ping")); 
ipv41.rmempty = true;
ipv41.optional=false;

ipv42 = d:option(Value, "ipv42", translate("IPv4 Server :"), translate("Second IPv4 server to ping")); 
ipv42.rmempty = true;
ipv42.optional=false;

ipv6 = d:option(Value, "ipv6", translate("IPv6 Server :"), translate("IPv6 server to ping")); 
ipv6.rmempty = true;
ipv6.optional=false;

return m