local modbus = require('lmodbus')

console.log(modbus.version())
local dev = modbus.new("COM8", 9600, 78, 8, 1)

console.log(dev)

dev:connect()
dev:setSlave(2)

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

dev:close()

