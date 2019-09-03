
local app = require("app")
local path = require("path")
local fs = require("fs")
local uv = require("luv")
local wot = require("wot")
local modbus = require("lmodbus")
local math = require("math")
local json = require("json")
local exports = {}

local messages={}


local postMessages

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




local function uart_recevie_callback()

    fs.read(fd, function(err, temp, bytesRead)
        -- console.printBuffer(temp)
        if(temp and #temp > 0) then
            if(ret) then
                ret = ret..temp
            else
                ret = temp
            end
        end      
        if(ret) then

            repeat
                local pos = string.find(ret, "H")
                if (pos) then
                    local data = {}
                    local size
                    if(pos+5 < #ret) then
                        size = string.byte(ret,pos+2) | string.byte(ret,pos+3)<<8
                    else
                        break
                    end
                    
                    if(size  and pos+size+3 <= #ret) then
                        for  i=1,size+4,1 do
                            data[i] = string.byte(ret,pos+i-1)
      
                        end
                        local crc =data[size+4]<<8 | data[size+3]
                        local crc16 = crc16_calculate(data,size+2)

                        if(crc ~= crc16) then
                            break
                        else
                            local analysis_data = string.sub(ret,pos+1,pos+size+1)
                            postMessages(analysis_data)
                        end
                            ret = string.sub(ret,pos+size+4,#ret)
                    else
                        break
                    end
                else
                    break
                end
            until(0)

        end

    end)
end

local function initBluetoothUart(cb)
    local dev = modbus.new("/dev/ttyAMA2", 115200, 78, 8, 1) -- N: 78, O: 79, E: 69
    dev:connect()
    fd = dev:uart_fd()
    local uart = uv.new_poll(fd)
    postMessages = cb
    uv.poll_start(uart, "r", uart_recevie_callback)


end

local function getFromUart()
    return json.encode(messages)
end

exports.initUart = initBluetoothUart

return exports