local utl = require "luci.util"

m = Map("custom", translate("Bandwidth Allocation"), translate("Set Maximum Bandwidth Usage before Internet blockage"))

m.on_after_save = function(self)
	luci.sys.call("/usr/lib/bwmon/allocate.sh 0 &")
end

s = m:section(TypedSection, "bwallocate", " ")
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

act = s:option(ListValue, "action", translate("Internet Action : "), translate("Action taken when allocation is exceeded"))
act.rmempty = true
act:value("0", "Internet Blocked")
act:value("1", "Internet Throttled")
act.default = "0"

down = s:option(Value, "down", "Download Speed in Mbps :");
down.optional=false; 
down.rmempty = true;
down.datatype = "and(uinteger,min(1),max(999))"
down:depends("action", "1")
down.default = "5"

up = s:option(Value, "up", "Upload Speed in Mbps :");
up.optional=false; 
up.rmempty = true;
up.datatype = "and(uinteger,min(1),max(999))"
up:depends("action", "1")
up.default = "2"

return m