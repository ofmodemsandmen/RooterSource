local utl = require "luci.util"
local uci = require "luci.model.uci".cursor()
local sys   = require "luci.sys"

m = Map("gps", translate("GPS Information"),
	translate("View GPS information and configure display"))

m.on_after_commit = function(self)
	luci.sys.call("/usr/lib/gps/change.sh &")
end
	
di = m:section(TypedSection, "configuration", translate(" "), translate(" "))
di.anonymous = true
di:tab("data", translate("GPS Information"))
di:tab("gpsconfig", translate("GPS Configuration"))
di:tab("config", translate("Report Configuration"))

this_tab = "data"

sx = di:taboption(this_tab, Value, "_dmy1", translate(" "))
sx.template = "gps/gps"

this_tab = "gpsconfig"

sxx = di:taboption(this_tab, Value, "_dmy2", translate(" "))
sxx.template = "gps/space"

c1 = di:taboption(this_tab, ListValue, "convert", translate("Latitude and Longitude Format"), translate("Use Degrees or Decimal format"));
c1:value("0", translate("Degrees/Minutes/Seconds"))
c1:value("1", translate("Decimal"))
c1.default=0

cd1 = di:taboption(this_tab, ListValue, "datefor", translate("Format of Date"), translate("Format used to display date"));
cd1:value("0", translate("Year-Month-Day"))
cd1:value("1", translate("Day/Month/Year"))
cd1.default=0

interval = di:taboption(this_tab, Value, "zoom", translate("Default Map Zoom"), translate("Zoom level of map from 1 (least) to 22 (most).")); 
interval.datatype = 'range(1,22)';
interval.default="15";

int = di:taboption(this_tab, Value, "refresh", translate("Information Refresh Interval"), translate("Amount of time in seconds between getting GPS information . Range is 10 to 500")); 
int.datatype = 'range(10,500)';
int.default="15";

return m
