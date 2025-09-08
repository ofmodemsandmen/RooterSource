#!/usr/bin/lua

baselat1 = arg[1]
baselon1 = arg[2]
lat1 = arg[3]
lon1 = arg[4]
precision1 = arg[5]
precision = tonumber(precision1) / 100000

pbaselat = tonumber(baselat1) + precision
mbaselat = tonumber(baselat1) - precision
pbaselon = tonumber(baselon1) + precision
mbaselon = tonumber(baselon1) - precision

lat = tonumber(lat1)
lon = tonumber(lon1)
baselat = tonumber(baselat1)
baselon = tonumber(baselon1)

local tfile = io.open("/tmp/compare", "w")
if lat == baselat and lon == baselon then
	tfile:write("COMPARE=\"", "0", "\"\n")
else
	if lat <= mbaselat or lat >= pbaselat then
		tfile:write("COMPARE=\"", "1", "\"\n")
	else
		if lon <= mbaselon or lon >= pbaselon then
			tfile:write("COMPARE=\"", "1", "\"\n")
		end
	end
end
tfile:write("PBASELAT=\"", tostring(pbaselat), "\"\n")
tfile:write("MBASELAT=\"", tostring(mbaselat), "\"\n")
tfile:write("PBASELON=\"", tostring(pbaselon), "\"\n")
tfile:write("MBASELON=\"", tostring(mbaselon), "\"\n")
tfile:write("LAT=\"", tostring(lat), "\"\n")
tfile:write("LON=\"", tostring(lon), "\"\n")
tfile:write("BASELAT=\"", tostring(baselat), "\"\n")
tfile:write("BASELON=\"", tostring(baselon), "\"\n")
tfile:close()