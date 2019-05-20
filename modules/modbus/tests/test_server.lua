local modbus = require('lmodbus')

console.log(modbus.version())

local dev = modbus.new("COM3", 9600, 78, 8, 1)

console.log(dev)

local ret = dev:connect()
console.log('connect', ret)

dev:slave(2)

dev:mapping(0, 100);
dev:set_value(2, 0, 1);
dev:set_value(2, 1, 2);
dev:set_value(2, 2, 3);

while (true) do
    ret = dev:receive()
    rawPrint('receive', ret)
end

setTimeout(5000, function() end)