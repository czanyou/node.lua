
local app = require("app")
local path = require("path")
local fs = require("fs")
local uv = require("luv")
local wot = require("wot")
local modbus = require("lmodbus")
local math = require("math")
local json = require("json")
local exports = {}

local dataReady = 0
local bluetoothWebthing = {}
local timer


local function sensorPropertiesAnalysis(msg)
    local sensor_info = {}
    local sensor_index = 1
    local sensor_class = 0x00
    local sensor_type = string.unpack('B',msg,sensor_index) 
    if (sensor_type == 0xff) then
        sensor_class =  string.unpack('B',msg,sensor_index+1) 
        sensor_index = sensor_index+2
    end

    while (sensor_index < #msg) do
        sensor_type = string.unpack('B',msg,sensor_index)
        if (sensor_class == 0x00) then
            if (sensor_type == 0x01) then
                sensor_info.batteryVoltage = string.unpack('>I2',msg,sensor_index + 1) 
                sensor_index = sensor_index + 3

            elseif (sensor_type == 0x02) then

                sensor_info.temperature = string.unpack('B',msg,sensor_index + 1) + string.unpack('B',msg,sensor_index + 2) / 255 
                sensor_index = sensor_index + 3

            elseif (sensor_type == 0x03) then

                sensor_info.humidity = string.unpack('B',msg,sensor_index+1)
                sensor_index = sensor_index + 2

            elseif (sensor_type == 0x04) then

                sensor_info.pressure = (string.unpack('B',msg,sensor_index + 1) * 65536 + string.unpack('>I2',msg,sensor_index + 2) ) / 100
                sensor_index = sensor_index + 4

            elseif (sensor_type == 0x07) then

                sensor_info.so2 =  string.unpack('B',msg,sensor_index + 1) + string.unpack('B',msg,sensor_index + 2) / 255 
                sensor_index = sensor_index + 3

            elseif (sensor_type == 0x08) then

                sensor_info.nh3 =  string.unpack('B',msg,sensor_index + 1) + string.unpack('B',msg,sensor_index + 2) / 255 
                sensor_index = sensor_index + 3
                
            elseif (sensor_type == 0x09) then

                sensor_info.h2s =  string.unpack('B',msg,sensor_index + 1) + string.unpack('B',msg,sensor_index + 2) / 255 
                sensor_index = sensor_index + 3

            elseif (sensor_type == 0x0a) then

                sensor_info.co2 =  string.unpack('B',msg,sensor_index + 1) + string.unpack('B',msg,sensor_index + 2) / 255 
                sensor_index = sensor_index + 3

            elseif (sensor_type == 0x0b) then

                sensor_info.ch2o =  string.unpack('B',msg,sensor_index + 1) + string.unpack('B',msg,sensor_index + 2) / 255 
                sensor_index = sensor_index + 3

            elseif (sensor_type == 0x0c) then

                sensor_info.pm25 =  string.unpack('B',msg,sensor_index + 1) + string.unpack('B',msg,sensor_index + 2) / 255 
                sensor_index = sensor_index + 3
            else
                break
            end
        
        elseif (sensor_class == 0x01) then
            if (sensor_type == 0x01) then
                sensor_info.batteryVoltage = string.unpack('>I2',msg,sensor_index + 1) 
                sensor_index = sensor_index + 3

            elseif (sensor_type == 0x02) then
                sensor_info.temperature = string.unpack('B',msg,sensor_index + 1) + string.unpack('B',msg,sensor_index + 2) / 255 
                sensor_index = sensor_index + 3

            elseif (sensor_type == 0x03) then

                sensor_info.humidity = string.unpack('B',msg,sensor_index+1)
                sensor_index = sensor_index + 2
            else
                break
            end
        elseif (sensor_class == 0x05) then
            if (sensor_type == 0x06) then
                if (string.unpack('B',msg,sensor_index + 1) == 0x00 ) then
                    sensor_info.open =  false
                else
                    sensor_info.open =  true
                end
                sensor_index = sensor_index + 2
            else
                break
            end

        elseif (sensor_class == 0x06) then
            if (sensor_type == 0x05) then
                if (string.unpack('B',msg,sensor_index + 1) == 0x00 ) then
                    sensor_info.alarm =  false
                else
                    sensor_info.alarm =  true
                end
                sensor_index = sensor_index + 2
            else
                break
            end
        else
        end
    end
    return sensor_info
    
end



local function boardcastAnalysis(webThing,white_list,msg)
    local flag = 0
    local size = string.unpack('<I2',msg,1)
    local i
    local data = {}
    bluetoothWebthing = webThing

    for  i =0 , 6 do
        data[i] = string.byte(msg, i+2)
    end

    local rssi = string.unpack('b',msg,#msg)
    local mac = string.format("%02x%02x%02x%02x%02x%02x", data[1], data[2], data[3], data[4], data[5], data[6])
    -- console.log(mac,white_list)
    for  k, v in ipairs(white_list) do
        if (string.find(v,mac) ~= nil) then
            flag = 1
            break
        end
    end
    
    if(flag == 0) then
        return
    else
        flag = 0
    end

    if(timer) then
        clearTimeout(timer)
    end
    dataReady = 1
    timer = setTimeout(5000,function()
        dataReady = 0
    end)

    local packet_type
    local index = 9

    while(index < size) do
        local frame_type
        local chunk_size = string.unpack('B',msg,index)
        local chunk_type = string.unpack('B',msg,index + 1)
        if (chunk_size == 0 ) then
            break
        end
        if (chunk_type == 0x01) then
            packet_type = 0x01
        end
        if (chunk_type == 0xff)then
                frame_type = string.unpack('B',msg,index+5)
        end

        if (chunk_type == 0xff and frame_type == 0x02 and packet_type == 0x01) then
            local result = {}
            result = sensorPropertiesAnalysis(string.sub(msg,index + 6,#msg - 1))
            dataReady = 1
            console.log(result)
            result.rssi = rssi
            bluetoothWebthing[mac]:sendStream(result)
        end
        index = index + chunk_size + 1
    end

    
end



function exports.dataStatus()
    console.log(dataReady)
    return dataReady
end

exports.analysisMsg = boardcastAnalysis

return exports
