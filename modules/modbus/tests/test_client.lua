local modbus = require('lmodbus')

console.log(modbus.version())
local dev = modbus.new("COM8", 9600, 78, 8, 1)

console.log(dev)

dev:connect()
dev:slave(2)

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

dev:close()

