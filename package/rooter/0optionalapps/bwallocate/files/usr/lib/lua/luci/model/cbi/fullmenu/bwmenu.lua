local utl = require "luci.util"

m = Map("custom", translate("Bandwidth Allocation"), translate("Set Maximum Bandwidth Usage before Internet blockage"))

m.on_after_save = function(self)
	luci.sys.call("/usr/lib/bwmon/allocate.sh 0 &")
	luci.sys.call("/usr/lib/bwmon/editemail.sh &")
end

s = m:section(TypedSection, "bwallocate", "Allocation Settings")
s.anonymous = true
s.addremove = false

s:option(Flag, "enabled", translate("Allocation Enabled : "))

maxim = s:option(Value, "allocate", translate("Maximum Bandwidth in GB : "), translate("Maximum amount of bandwidth that can be used before Internet is affected")); 
maxim.rmempty = true;
maxim.optional=false;
maxim.default="1000";
maxim.datatype = "and(uinteger,min(1))"

rollover = s:option(ListValue, "rollover", translate("Rollover Day : "), translate("Day of the month when bandwidth usage resets"))
rollover.rmempty = true
rollover:value("1", "1st")
rollover:value("2", "2nd")
rollover:value("3", "3rd")
rollover:value("4", "4th")
rollover:value("5", "5th")
rollover:value("6", "6th")
rollover:value("7", "7th")
rollover:value("8", "8th")
rollover:value("9", "9th")
rollover:value("10", "10th")
rollover:value("11", "11th")
rollover:value("12", "12th")
rollover:value("13", "13th")
rollover:value("14", "14th")
rollover:value("15", "15th")
rollover:value("16", "16th")
rollover:value("17", "17th")
rollover:value("18", "18th")
rollover:value("19", "19th")
rollover:value("20", "20th")
rollover:value("21", "21th")
rollover:value("22", "22th")
rollover:value("23", "23th")
rollover:value("24", "24th")
rollover:value("25", "25th")
rollover:value("26", "26th")
rollover:value("27", "27th")
rollover:value("28", "28th")
rollover.default = "1"

act = s:option(ListValue, "meth", translate("Throttling Determined By : "), translate("Method used to determine throttling"))
act.rmempty = true
act:value("0", "Current Bandwidth Used")
act:value("1", "Projected Bandwidth Used")
act.default = "0"

s = m:section(TypedSection, "throttle", translate("Throttle Levels"), translate("Set throttling by amount of bandwidth used or projected"))
s.anonymous = true
s.addremove = true

name = s:option(Value, "name", translate("Throttle Level Name"), translate("Optional Name"))

limit = s:option(Value, "limit", translate("Amount in GB :"), translate("Apply throttle when Bandwidth used or projected exceeds this amount"))
limit.datatype = "uinteger"
limit.default="100"

throt = s:option(Value, "throttle", translate("Throttle Speed in Mbps :"), translate("Speed to throttle to when amount is exceeded"))
throt.default="0"
throt.datatype = "ufloat"

return m