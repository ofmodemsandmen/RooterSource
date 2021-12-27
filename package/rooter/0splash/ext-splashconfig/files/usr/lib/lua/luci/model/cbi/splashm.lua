

local sys   = require "luci.sys"
local zones = require "luci.sys.zoneinfo"
local fs    = require "nixio.fs"
local conf  = require "luci.config"

m = Map("iframe", "Splash Screen Configuration",translate("Change the configuration of the Splash and Login screen."))
m:chain("luci")
	
s = m:section(TypedSection, "iframe", "Status Page Configuration")
s.anonymous = true
s.addremove = false

c1 = s:option(ListValue, "splashpage", "Enable Network Status Page Before Login :");
c1:value("0", "Disabled")
c1:value("1", "Enabled")
c1.default=0

a1 = s:option(Value, "splashtitle", "Network Status Title :"); 
a1.optional=false;
a1.default = "ROOter Status"
a1:depends("splashpage", "1")


ss = m:section(TypedSection, "login", "Login Page Configuration")
ss.anonymous = true
ss.addremove = false

dc1 = ss:option(ListValue, "logframe", "Enable Login Page Window : ");
dc1:value("0", "Disabled")
dc1:value("1", "Enabled")
dc1.default=0

d1 = ss:option(ListValue, "logtype", "Type of Window : ");
d1:value("1", "Bandwidth Statistics")
d1:value("2", "Image")
d1:value("3", "OpenSpeedTest")
d1.default=1
d1:depends("logframe", "1")

e1 = ss:option(Value, "logimage", "Image Name :"); 
e1.optional=false;
e1.default = "open.png"
e1:depends("logtype", "2")

d1 = ss:option(ListValue, "logimagepos", "Position in Window : ");
d1:value("absmiddle", "Absolute Middle")
d1:value("middle", "Middle")
d1:value("left", "Left")
d1:value("right", "Right")
d1:value("top", "Top")
d1:value("bottom", "Bottom")
d1.default="absmiddle"
d1:depends("logtype", "2")
	
return m