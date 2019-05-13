local modbus = require('lmodbus')

console.log(modbus.version())

dev=modbus.new("COM3",9600)
-- dev=modbus.new("127.0.0.1", 502)

console.log(dev)

dev:connect()
dev:slave(2)

--[[
addr={}
for i = 1,9 do
    table.insert(addr, i)
end

--query all the value of the address in the list.
value_table=dev:read(addr)
console.log(value_table)

for k,v in pairs(value_table) do
    print(k, v)
end

msg = {[6]=258, [7]=258}
dev:write(msg)

--]]
--query address 7 and 8

local data = dev:mread(0,1)
console.printBuffer(data)
local value = string.unpack('<I2', data)
console.log(value * 0.1)

local data = dev:mread(1,1)
console.printBuffer(data)
local value = string.unpack('<i2', data)
console.log(value * 0.1)

local data = dev:mread(6,1)
console.printBuffer(data)
local value = string.unpack('<I2', data)
console.log(value)

--[[
--write value 0 in address 9
dev:mwrite('mwrite', 9,0)
--]]

dev:close()

