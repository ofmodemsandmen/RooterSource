#!/usr/bin/lua

array={}
file = io.open("/tmp/ttyp", "r")
line = file:read("*line")
while line do
	n = string.len(line)
	if n < 8 then
		num = string.sub(line,7)
		line = string.sub(line,1,6) .. "0" .. num
	end
	array[#array + 1] = line
	line = file:read("*line")
end
file:close()
table.sort(array)

file = io.open("/tmp/ttyp", "w")
for j=1, #array do
	n = string.len(array[j])
	if n == 8 then
		num = string.sub(array[j],7,7)
		if num == "0" then
			num = string.sub(array[j],8)
			array[j] = string.sub(array[j],1,6) .. num
		end
	end
	file:write(array[j] .. "\n")
end
file:close()