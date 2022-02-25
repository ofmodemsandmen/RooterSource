local utl = require "luci.util"

m = Map("custom", translate("Bandwidth Allocation"), translate("Set Maximum Bandwidth Usage before Internet blockage"))

m.on_after_save = function(self)
	luci.sys.call("/usr/lib/bwmon/allocate.sh 0 &")
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

s = m:section(TypedSection, "texting", "Texting Settings")
s.anonymous = true
s.addremove = false

aact = s:option(ListValue, "text", translate("Text Usage : "), translate("Text usage to a phone"))
aact.rmempty = true
aact:value("0", "No")
aact:value("1", "Yes")
aact.default = "0"


pph = s:option(Value, "ident", "Identifier :");
pph.optional=false; 
pph.rmempty = true;
pph:depends("text", "1")
pph.default = "xxx"

ph = s:option(Value, "phone", "Phone Number :");
ph.optional=false; 
ph.rmempty = true;
ph.datatype = "phonedigit"
ph:depends("text", "1")
ph.default = "0"

ct = s:option(ListValue, "method", translate("Method : "), translate("Method used to determine when to text"))
ct.rmempty = true
ct:value("0", "By Specified Time")
ct:value("1", "By Amount Used")
ct.default = "0"
ct:depends("text", "1")

sdhour = s:option(ListValue, "time", translate("Texting Time :"), translate("Time to send text"))
sdhour.rmempty = true
sdhour:value("0", "12:00 AM")
sdhour:value("1", "12:15 AM")
sdhour:value("2", "12:30 AM")
sdhour:value("3", "12:45 AM")
sdhour:value("4", "01:00 AM")
sdhour:value("5", "01:15 AM")
sdhour:value("6", "01:30 AM")
sdhour:value("7", "01:45 AM")
sdhour:value("8", "02:00 AM")
sdhour:value("9", "02:15 AM")
sdhour:value("10", "02:30 AM")
sdhour:value("11", "02:45 AM")
sdhour:value("12", "03:00 AM")
sdhour:value("13", "03:15 AM")
sdhour:value("14", "03:30 AM")
sdhour:value("15", "03:45 AM")
sdhour:value("16", "04:00 AM")
sdhour:value("17", "04:15 AM")
sdhour:value("18", "04:30 AM")
sdhour:value("19", "04:45 AM")
sdhour:value("20", "05:00 AM")
sdhour:value("21", "05:15 AM")
sdhour:value("22", "05:30 AM")
sdhour:value("23", "05:45 AM")
sdhour:value("24", "06:00 AM")
sdhour:value("25", "06:15 AM")
sdhour:value("26", "06:30 AM")
sdhour:value("27", "06:45 AM")
sdhour:value("28", "07:00 AM")
sdhour:value("29", "07:15 AM")
sdhour:value("30", "07:30 AM")
sdhour:value("31", "07:45 AM")
sdhour:value("32", "08:00 AM")
sdhour:value("33", "08:15 AM")
sdhour:value("34", "08:30 AM")
sdhour:value("35", "08:45 AM")
sdhour:value("36", "09:00 AM")
sdhour:value("37", "09:15 AM")
sdhour:value("38", "09:30 AM")
sdhour:value("39", "09:45 AM")
sdhour:value("40", "10:00 AM")
sdhour:value("41", "10:15 AM")
sdhour:value("42", "10:30 AM")
sdhour:value("43", "10:45 AM")
sdhour:value("44", "11:00 AM")
sdhour:value("45", "11:15 AM")
sdhour:value("46", "11:30 AM")
sdhour:value("47", "11:45 AM")
sdhour:value("48", "12:00 PM")
sdhour:value("49", "12:15 PM")
sdhour:value("50", "12:30 PM")
sdhour:value("51", "12:45 PM")
sdhour:value("52", "01:00 PM")
sdhour:value("53", "01:15 PM")
sdhour:value("54", "01:30 PM")
sdhour:value("55", "01:45 PM")
sdhour:value("56", "02:00 PM")
sdhour:value("57", "02:15 PM")
sdhour:value("58", "02:30 PM")
sdhour:value("59", "02:45 PM")
sdhour:value("60", "03:00 PM")
sdhour:value("61", "03:15 PM")
sdhour:value("62", "03:30 PM")
sdhour:value("63", "03:45 PM")
sdhour:value("64", "04:00 PM")
sdhour:value("65", "04:15 PM")
sdhour:value("66", "04:30 PM")
sdhour:value("67", "04:45 PM")
sdhour:value("68", "05:00 PM")
sdhour:value("69", "05:15 PM")
sdhour:value("70", "05:30 PM")
sdhour:value("71", "05:45 PM")
sdhour:value("72", "06:00 PM")
sdhour:value("73", "06:15 PM")
sdhour:value("74", "06:30 PM")
sdhour:value("75", "06:45 PM")
sdhour:value("76", "07:00 PM")
sdhour:value("77", "07:15 PM")
sdhour:value("78", "07:30 PM")
sdhour:value("79", "07:45 PM")
sdhour:value("80", "08:00 PM")
sdhour:value("81", "08:15 PM")
sdhour:value("82", "08:30 PM")
sdhour:value("83", "08:45 PM")
sdhour:value("84", "09:00 PM")
sdhour:value("85", "09:15 PM")
sdhour:value("86", "09:30 PM")
sdhour:value("87", "09:45 PM")
sdhour:value("88", "10:00 PM")
sdhour:value("89", "10:15 PM")
sdhour:value("90", "10:30 PM")
sdhour:value("91", "10:45 PM")
sdhour:value("92", "11:00 PM")
sdhour:value("93", "11:15 PM")
sdhour:value("94", "11:30 PM")
sdhour:value("95", "11:45 PM")
sdhour:depends("text", "1")
sdhour.default = "48"

xct = s:option(ListValue, "days", translate("Interval : "), translate("Number of days between texts"))
xct.rmempty = true
xct:value("1", "Every Day")
xct:value("2", "Every 2 Days")
xct:value("5", "Every 5 Days")
xct:value("10", "Every 10 Days")
xct:value("15", "Every 15 Days")
xct.default = "5"
xct:depends("method", "0")

xxct = s:option(ListValue, "increment", translate("Increment : "), translate("Amount Used between texts"))
xxct.rmempty = true
xxct:value("50", "Every 50 GB")
xxct:value("75", "Every 75 GB")
xxct:value("100", "Every 100 GB")
xxct.default = "50"
xxct:depends("method", "1")

return m