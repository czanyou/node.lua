local modbus = require('lmodbus')

console.log('version', modbus.version())
local dev = modbus.new("COM8", 9600, 78, 8, 1)

console.log('device:', dev)

dev:connect()

local slave = dev:getSlave();
console.log('slave:', slave)

local timeout = dev:getTimeout();
console.log('timeout:', timeout)

dev:setSlave(2)
dev:setTimeout(1000)
dev:setTimeout(2000, 2)

local slave = dev:getSlave();
console.log('slave:', slave)

local timeout = dev:getTimeout();
console.log('timeout:', timeout)

local timeout = dev:getTimeout(2);
console.log('timeout:', timeout)

local data = dev:readRegisters(0,1)

if (data) then
    console.printBuffer(data)
    local value = string.unpack('>I2', data)
    console.log(value * 0.1)

    data = dev:readRegisters(1,1)
    console.printBuffer(data)
    value = string.unpack('>i2', data)
    console.log(value * 0.1)

    data = dev:readRegisters(6,1)
    console.printBuffer(data)
    value = string.unpack('>I2', data)
    console.log(value)
end

dev:close()

