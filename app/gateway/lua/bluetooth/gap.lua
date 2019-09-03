
-- local function uart_recevie_callback()
--     local function boardcast_analysis(packet_data)
--         local packet_type = 0x00
--         local data = {}
--         local size = #packet_data
--         local i
--         local flag = 0
--         for i = 1, size do
--             data[i] = string.byte(packet_data, i)

--         end
--         local rssi = data[size] - 256
--         local mac = string.format("%02x%02x%02x%02x%02x%02x", data[1], data[2], data[3], data[4], data[5], data[6])
      
--         for  k, v in ipairs(white_list) do
--             if(string.find(v,mac) ~= nil)
--             then
--                 flag = 1
--                 break
--             end
--         end

--         if(flag == 1 and size > 0)
--         then
--             console.log(mac, rssi)
--             if(timer) then
--                 clearTimeout(timer)
--             end
--             dataReady = 1
--             timer = setTimeout(5000,function()
--                 dataReady = 0
--             end)
--             flag = 0
--             local index = 7
--             while(index < size)
--             do
--                 local chunk_size = data[index]
--                 local chunk_type = data[index+1]
--                 local frame_type = data[index+5]
--                 if(chunk_size == 0 )
--                 then
--                     break
--                 end

--                 if(chunk_type == 0x01)
--                 then
--                     packet_type = 0x01

--                 end
--                 if(chunk_type == 0xff)
--                 then
--                     local frame_type = data[index+5]
--                 end

--                 if(chunk_type == 0xff and frame_type == 0x02 and packet_type == 0x01)
--                 then
--                     local sensor_info = {}
--                     local sensor_index = 6
--                     local sensor_class = 0x00

--                     sensor_type = data[index+sensor_index]
--                     if(sensor_type == 0xff) then
--                         sensor_class =  data[index+sensor_index+1]
--                         sensor_index = sensor_index+2
--                     end

--                     -- console.printBuffer(data)

--                     while(sensor_index < chunk_size )
--                     do
--                         sensor_type = data[index+sensor_index]
--                         if (sensor_class == 0x00) then 
--                             if(sensor_type == 0x01) then
--                                 sensor_info.batteryVoltage = data[index+sensor_index+1]*255+data[index+sensor_index+2]
--                                 sensor_index = sensor_index+3

--                             elseif(sensor_type == 0x02) then

--                                 sensor_info.temperature = data[index+sensor_index+1]+data[index+sensor_index+2]/255
--                                 sensor_index = sensor_index+3

--                             elseif(sensor_type == 0x03) then

--                                 sensor_info.humidity = data[index+sensor_index+1]
--                                 sensor_index = sensor_index+2

--                             elseif(sensor_type == 0x04) then

--                                 sensor_info.pressure = (data[index+sensor_index+1]*65536 +data[index+sensor_index+2]*256+data[index+sensor_index+3])/100
--                                 sensor_index = sensor_index+4

--                             elseif(sensor_type == 0x07) then

--                                 sensor_info.so2 =  data[index+sensor_index+1]+data[index+sensor_index+2]/255
--                                 sensor_index = sensor_index+3

                                
--                             elseif(sensor_type == 0x08) then

--                                 sensor_info.nh3 =  data[index+sensor_index+1]+data[index+sensor_index+2]/255
--                                 sensor_index = sensor_index+3

                                
--                             elseif(sensor_type == 0x09) then

--                                 sensor_info.h2s =  data[index+sensor_index+1]+data[index+sensor_index+2]/255
--                                 sensor_index = sensor_index+3

--                             elseif(sensor_type == 0x0a) then

--                                 sensor_info.co2 =  data[index+sensor_index+1]+data[index+sensor_index+2]/255
--                                 sensor_index = sensor_index+3

--                             elseif(sensor_type == 0x0b) then

--                                 sensor_info.ch2o =  data[index+sensor_index+1]+data[index+sensor_index+2]/255
--                                 sensor_index = sensor_index+3

--                             elseif(sensor_type == 0x0c) then

--                                 sensor_info.pm25 =  data[index+sensor_index+1]+data[index+sensor_index+2]/255
--                                 sensor_index = sensor_index+3
--                             else
--                                 console.log(string.format("null:%02x",sensor_type))
--                                 break
--                             end
--                         elseif (sensor_class == 0x01) then 
                            
--                             if(sensor_type == 0x01) then
--                                 sensor_info.batteryVoltage = data[index+sensor_index+1]*255+data[index+sensor_index+2]
--                                 sensor_index = sensor_index+3

--                             elseif(sensor_type == 0x02) then

--                                 sensor_info.temperature = data[index+sensor_index+1]+data[index+sensor_index+2]/255
--                                 sensor_index = sensor_index+3

--                             elseif(sensor_type == 0x03) then

--                                 sensor_info.humidity = data[index+sensor_index+1]
--                                 sensor_index = sensor_index+2
--                             end
--                         elseif (sensor_class == 0x02) then 

--                         elseif (sensor_class == 0x03) then 
                     
--                         elseif (sensor_class == 0x04) then

--                         elseif (sensor_class == 0x05) then 
--                             if(sensor_type == 0x06) then
--                                 if(data[index+sensor_index+1] == 0x00) then
--                                     sensor_info.open =  false
--                                 else
--                                     sensor_info.open =  true 
--                                 end
--                                 sensor_index = sensor_index+2
--                             else
--                                 break
--                             end

--                         elseif (sensor_class == 0x06) then 
--                             if(sensor_type == 0x05) then
--                                 if(data[index+sensor_index+1] == 0x00) then
--                                     sensor_info.alarm =  false
--                                 else
--                                     sensor_info.alarm =  true 
--                                 end
--                                 sensor_index = sensor_index+2
--                             else
--                                 break
--                             end
--                         end
--                     end
--                     sensor_info.rssi = rssi
--                     -- console.log(app.bluetoothDevices)
--                     app.bluetoothDevices[mac]:sendStream(sensor_info)
--                     console.log(sensor_info)

--                 end

--                 index = index+chunk_size+1

--             end
--         end
--     end

--     local function config_analysis(packet_data)
--         console.log("config_analysis")
--     end

--     local function slave_analysis(packet_data)
--         console.log("slave_analysis")
--     end

--     local function rowdata_analysis(packet_data)
--         local channel = string.byte(packet_data, 1)
--         local code = string.byte(packet_data, 4)
--         local seq_t = string.byte(packet_data, 5)
--         local size = string.byte(packet_data, 2) | string.byte(packet_data, 3) << 8
--         if (size >= 4) then
--             local analysis_data = string.sub(packet_data, 4, 5 + size - 4)

--             if (channel == 0xff) then
                
--                 boardcast_analysis(analysis_data)
                
--             elseif (channel == 0x00) then
--                 -- console.log(analysis_data)
--                 if (code == 0x0a) then
              
--                     if (string.find(analysis_data,'ok') ~= nil ) then
--                         bluetoothRdady = 1
--                     end

--                     -- if(deviceStatusTimer) then
--                     --     clearTimeout(deviceStatusTimer)
--                     -- end
--                     -- deviceStatusTimer = setTimeout(5000,function()
--                     --     bluetoothStatus = 0


--                     -- if(size <= 4) then
--                     --     setBluetoothConfig(0x01, "scan=,0D0611")
--                     -- end
                    
--                 else
--                     config_analysis(analysis_data)
--                 end
--             -- else
--             --     if(code == 0x0a  )
--             --     then
--             --         console.log(analysis_data);
--             --     else
--             --         slave_analysis(analysis_data)
--             --     end
--             end
--         end
--     end



--     fs.read(fd, function(err, temp, bytesRead)
--         -- console.printBuffer(temp)
--         if(temp and #temp > 0) then
--             if(ret) then
--                 ret = ret..temp
--             else
--                 ret = temp
--             end
--         end      

--         if(ret) then

--             repeat
--                 local pos = string.find(ret, "H")
--                 if (pos) then
--                     local data = {}
--                     local size
--                     if(pos+5 < #ret) then
--                         size = string.byte(ret,pos+2) | string.byte(ret,pos+3)<<8
--                     else
--                         break
--                     end
                    
--                     if(size  and pos+size+3 <= #ret) then
--                         for  i=1,size+4,1 do
--                             data[i] = string.byte(ret,pos+i-1)
      
--                         end
--                         local crc =data[size+4]<<8 | data[size+3]
--                         local crc16 = crc16_calculate(data,size+2)

--                         if(crc ~= crc16) then
--                             break
--                         else
--                             local analysis_data = string.sub(ret,pos+1,pos+size+1)
                            
--                             rowdata_analysis(analysis_data)
--                         end
--                             ret = string.sub(ret,pos+size+4,#ret)
--                     else
--                         break
--                     end
--                 else
--                     break
--                 end
--             until(0)

--         end

--     end)
    


-- end

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
    console.log(mac,white_list)
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
        local chunk_type = string.unpack('B',msg,index+1)
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
            result = sensorPropertiesAnalysis(string.sub(msg,index+6,#msg-1))
            dataReady = 1
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
