
local app = require("app/init")
local path = require("path")
local fs = require("fs")
local uv = require("luv")
local wot = require("wot")
local modbus = require("lmodbus")
local math = require("math")
local button = require("./button")
local json = require("json")
local exports = {}



function crc16_calculate(data, len)
    local crc16 = 0xffff
    local temp, i, j
    for i = 1, len do
        crc16 = crc16 ~ data[i]
        for j = 1, 8 do
            if ((crc16 & 0x0001) == 1) then
                crc16 = (crc16 >> 1) ~ 0xa001
            else
                crc16 = crc16 >> 1
            end
        end
    end

    return crc16
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
    console.log(len)
    ret =
        string.char(start) ..
        string.char(channel) ..
            string.char(len & 0xff) .. string.char(len >> 8) .. string.char(code) .. string.char(seq)
    if (data ~= nil) then
        ret = ret .. data
    end

    for i = 1, len + 4 do
        temp[i] = string.byte(ret, i)
    end
    local crc = crc16_calculate(temp, len + 2)
    console.log(crc)
    ret = ret .. string.char(crc & 0xff) .. string.char(crc >> 8)

    fs.writeSync(fd, nil, ret)
    console.log("test")
end



local function uart_recevie_callback()
    fs.read(fd, function(err, temp, bytesRead)
        -- if(temp and #temp > 0) then
        --     if(ret) then
        --         ret = ret..temp
        --     else
        --         ret = temp
        --     end
        -- end     
        
        console.printBuffer(temp)
    end)
end


local function initBluetoothUart()
    local dev = modbus.new("/dev/ttyAMA2", 9600, 78, 8, 1) -- N: 78, O: 79, E: 69
    dev:connect()
    fd = dev:uart_fd()
    uart = uv.new_poll(fd)
    uv.poll_start(uart, "r", uart_recevie_callback)
    setInterval(100*60, function()
        setBluetoothConfig(0x01, "scan")
    end)

end

initBluetoothUart()