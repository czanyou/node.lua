local fs 	= require('fs')
local luv 	= require('luv')

local modbus = require('lmodbus')

local exports = {}

local uart_poll = nil
local uart_fd = nil

local buffer = '';
local state = 0;

local function uart_recevie_callback()

    local data = fs.read(uart_fd, function(err, data)
        -- console.log('data', err, #data, data)
        -- console.printBuffer(data)
        if (#data < 1) then
            return
        end

        buffer = buffer .. data
        if (#buffer < 4) then
            return
        end

        if (state == 0) then
            local index = buffer:find('H')
            console.log('index', index, #buffer)
            if (index and index > 0) then
                if (index > 1) then
                    buffer = buffer:sub(index)
                end

                state = 1
            end
        else
            console.printBuffer(buffer)
            local a, b, size =  string.unpack('<BBI2', buffer, 1)
            console.log(a, b, size)

            local endPos = size + 4
            if (#buffer >= endPos) then
                buffer = buffer:sub(endPos + 1)
            end

        end
    end)
end

local function setBluetoothConfig(code, data)
    local ret
    local i
    local start = 0x48
    local channel = 0x00
    local temp = {}
    math.randomseed(os.time())
    local seq = math.random(0, 255)

    local len = #data + 4
    -- console.log(len)
    ret = string.char(start) .. string.char(channel) .. string.char(len & 0xff) .. string.char(len >> 8) .. string.char(code) .. string.char(seq)
    if (data ~= nil) then
        ret = ret .. data
    end

    for i = 1, len + 4 do
        temp[i] = string.byte(ret, i)
    end

    local crc = crc16_calculate(temp, len + 2)
    -- console.log(uart_fd, crc);
    ret = ret .. string.char(crc & 0xff) .. string.char(crc >> 8)
    
    --console.printBuffer(ret)
    --console.log(fs.writeSync(uart_fd, nil, ret))
end

local function initUart()
    console.log(modbus.version())
    local filename = "/dev/ttyAMA2"
    if (not fs.existsSync(filename)) then
        filename = "/dev/ttyUSB0"
        if (not fs.existsSync(filename)) then
            return
        end
    end

    local uart = modbus.new(filename, 9600, 78, 8, 1) -- N: 78, O: 79, E: 69
    uart:connect()

    uart_fd = uart:getFD()
    print("fd", uart_fd)

    uart_poll = luv.new_poll(uart_fd)
    luv.poll_start(uart_poll, "r", uart_recevie_callback)

    -- setBluetoothConfig(0x01, "test")
    -- setBluetoothConfig(0x01, "scan=,0D0611")
end

function exports.test()
    initUart()
end

function exports.version()
    print("software: ", process.version)
    print("firmware: ", process.version)
end

function exports.button()

end

function exports.led()

end

function exports.dhcp()

end

function exports.register()

end

function exports.bluetooth()

end

return exports
