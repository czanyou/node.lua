local modbus = require('lmodbus')

console.log(modbus.version())

local dev=modbus.new("/dev/ttyUSB0", 9600)
-- dev=modbus.new("127.0.0.1", 502)

console.log(dev)

dev:connect()
dev:setSlave(2)

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

local data = dev:readRegisters(0,1)
console.printBuffer(data)
local value = string.unpack('<I2', data)
console.log(value * 0.1)

local data = dev:readRegisters(1,1)
console.printBuffer(data)
local value = string.unpack('<i2', data)
console.log(value * 0.1)

local data = dev:readRegisters(6,1)
console.printBuffer(data)
local value = string.unpack('<I2', data)
console.log(value)

--[[
--write value 0 in address 9
dev:writeRegister('writeRegister', 9,0)
--]]

dev:close()

