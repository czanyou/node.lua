
local path = require('path')
local fs = require('fs')
local uv     = require('luv')
local wot = require('wot')
local modbus = require('lmodbus')
local math = require('math')

local json      = require('json')
local exports={}

-- local uart_recevie_buf ={}
  
local sensor_list = {}


function crc16_calculate(data,len)
    local crc16 = 0xffff
    local temp,i,j
    for i = 1,len do
        crc16 = crc16 ~ data[i]
        for j = 1,8 do
            if ((crc16 & 0x0001) == 1)
            then 
                crc16 =(crc16 >>1) ~ 0xa001
            else
                crc16 = crc16 >>1
            end
        end
    end
    return crc16
end
    
-- local test = "123456�\n�\n�"

local test = {0x31,0x32,0x33,0x34,0x35,0x36,0x02,0x01,0x06,0x0E,0xFF,0x0D,0x06,0x11,0x02,0x02,0x20,0x0A,0x03,0x1A,0x04,0x00,0x00}


local function array2string(array,len)
    local ret
    ret = string.char(array[1])
    for i = 2,len do
        ret = ret..string.char(array[i])
    end
    return ret
end


local  boardcast_analyze 

local thing

function Sleep(n)
    os.execute("sleep " .. n)
 end

local function onread(data)
    print(data)
end

local function string_nocase_cmp(src,dest)
    return string.find(string.lower(src), string.lower(dest))
end

local function uart_recevie_callback()

    local function boardcast_analysis(packet_data)
        console.log (packet_data)
        console.log (#packet_data)
        local packet_type = 0x00
        local data = {}
        local size = #packet_data
        local i
        for  i =1,size do
            data[i] = string.byte(packet_data,i)
        end
        local mac = string.format("%02x%02x%02x%02x%02x%02x",data[1],data[2],data[3],data[4],data[5],data[6])
        console.log(mac)

        if(size > 0)
        then
            local index = 7
            while(index < size)
            do
                local chunk_size = data[index]
                local chunk_type = data[index+1]
                local frame_type = data[index+5]
                if(chunk_size == 0 )
                then
                    break
                end

                if(chunk_type == 0x01)
                then
                    packet_type = 0x01
                    console.log("boardcast packet")
                end
                if(chunk_type == 0xff)
                then
                    local frame_type = data[index+5]
                    -- console.log(string.format("frame_type:%02x",frame_type))
                end
                

                -- console.log(string.format("chunk_type:%02x,chunk_size:%02x",chunk_type,chunk_size))
                if(chunk_type == 0xff and frame_type == 0x02 and packet_type == 0x01)
                then 
                             
                    local sensor_info = {}    
                    local sensor_index = 6
                    while(sensor_index < chunk_size )
                    do
                        sensor_type = data[index+sensor_index]
                        if(sensor_type == 0x01)
                        then
                            sensor_info.batteryInfo = data[index+sensor_index+1]+data[index+sensor_index+2]/255
                            sensor_index = sensor_index+3
         
                        elseif(sensor_type == 0x02)
                        then
                            
           
                            sensor_info.temperature = data[index+sensor_index+1]+data[index+sensor_index+2]/255
                            sensor_index = sensor_index+3
                          
                        elseif(sensor_type == 0x03)
                        then
                  
                            sensor_info.humidity = data[index+sensor_index+1]
                            sensor_index = sensor_index+2
                            
                        elseif(sensor_type == 0x04)
                        then
                  
                            sensor_info.atmos = data[index+sensor_index+1]+data[index+sensor_index+2]/255
                            sensor_index = sensor_index+3
                   
                        else
                            console.log(string.format("null:%02x",sensor_type))
                            
                            break
                        end
                    end
                    if(sensor_info ~= nil)
                    then
                        local packet_info = {}
        
                        packet_info.did = mac
                        packet_info.type = "stream"
                        packet_info.data = sensor_info  
                        -- local packet_data = json.encode(packet_info)

                        console.log(sensor_info)
                        -- console.log(thing.client)
                        -- local client = self.client;
                        -- if (not client) or (not values) then
                        --     return


                        thing:sendStream(sensor_info)
                        console.log("end")
                    end
                end

                index = index+chunk_size+1
   
            end
        end
    end


    local function config_analysis(packet_data)
        console.log("config_analysis");
    end

    local function slave_analysis(packet_data)
        console.log("slave_analysis");
    end

    local function rowdata_analysis(packet_data)

        local channel = string.byte(packet_data,1)
        local code = string.byte(packet_data,4)
        local seq_t = string.byte(packet_data,5)
        local size = string.byte(packet_data,2) | string.byte(packet_data,3)<<8
        if(size > 4)
        then
            local analysis_data = string.sub(packet_data,4,5+size-4)
            console.log("channel"..channel)
            if(channel == 0xff)
            then
                -- boardcast_analysis(array2string(test,23))
                boardcast_analysis(analysis_data)
            elseif(channel == 0x00)
            then
                if(code == 0x0a  )
                then 
                    console.log(analysis_data);
                else
                    config_analysis(analysis_data)
                end
            else                              
                if(code == 0x0a  )
                then 
                    console.log(analysis_data);
                else
                    slave_analysis(analysis_data)
                end
            end
        end   
    end


    repeat
        local temp = fs.readSync(fd)
        if(temp and #temp > 0)
        then
            if(ret)
            then
                ret = ret..temp
            else
                ret = temp
            end
        else
            break
        end     
    until(0)

    if (ret ~= nil)
    then
        
    repeat
        local pos = string.find(ret, "H")
        if (pos)
        then
            local data = {}
            local size
            if(pos+4 < #ret)
            then       
                size = string.byte(ret,pos+2) | string.byte(ret,pos+3)<<8
            else
                break
            end            
            if(size  and pos+size+3 <= #ret)
            then                                                  
                for  i=1,size+4,1 do
                    data[i] = string.byte(ret,pos+i-1)
                end
                local crc =data[size+4]<<8 | data[size+3]
                local crc16 = crc16_calculate(data,size+2)
                if(crc ~= crc16)
                then
                    console.log ("crc error crc"..crc.."  crc16"..crc16)
                    break
                end
                local analysis_data = string.sub(ret,pos+1,pos+size+1)
                rowdata_analysis(analysis_data)            
                ret = string.sub(ret,pos+size+4,#ret)
            else
                break
            end
        else
            break
        end
    until(0)
    end
    
end



local function initBluetoothUart()
    console.log(modbus.version())
    local dev = modbus.new("/dev/ttyAMA2", 9600, 78, 8, 1)    -- N: 78, O: 79, E: 69
    dev:connect()
    fd = dev:uart_fd()
    print("fd"..fd)
    uart = uv.new_poll(fd)
    uv.poll_start(uart, "rw", uart_recevie_callback)
end


local function setBluetoothConfig(code,data)

    local ret
    local i
    local start = 0x48
    local channel = 0x00
    local temp ={}
    math.randomseed(os.time())
    local seq = math.random(0,255)

    local len = #data+4
    console.log(len)
    ret = string.char(start)..string.char(channel)..string.char(len&0xff)..string.char(len>>8)..string.char(code)..string.char(seq)
    if(data ~= nil)
    then
        ret =ret..data
    end

    for i = 1 ,len+4 do
        temp[i] = string.byte(ret,i)
    
    end
    local crc = crc16_calculate(temp,len+2)
    console.log(crc);
    ret = ret..string.char(crc&0xff)..string.char(crc>>8)
    

    fs.writeSync(fd,nil,ret)
end

local function CheckButtonState(interval_ms)
    setInterval(interval_ms, function()
        local path =  "/sys/class/gpio/gpio62/value"
        local source = fs.openSync(path, 'r', 438)
        local result = fs.readSync(source)
        fs.closeSync(source)
        state= tonumber(string.match(result,'(%d)\n'))
        console.log(state) 
    end)
end




local function createBluetoothThing(options)
    if (not options) then
        return nil, 'need options'

    elseif (not options.mqtt) then
        return nil, 'need MQTT url option'

    elseif (not options.did) then
        return nil, 'need did option'
    end

    local gateway = { 
        id = options.did, 
        url = options.mqtt,
        name = options.name or 'bluetooth',
        actions = {},
        properties = {},
        events = {}
    }

    local webThing = wot.produce(gateway)
    webThing.secret = options.secret

 
    webThing:expose()

    webThing:on('register', function(response)
        local result = response and response.result
        if (result and result.code and result.error) then
            console.log('register', 'error', response.did, result)

        elseif (result.token) then
            console.log('register', response.did, result.token)
        end
    end)

    initBluetoothUart()
    setBluetoothConfig(0x01,"scan=,0D0611")
    return webThing

end


 
    CheckButtonState(1000)


    local options={}
    options.did = 'f22b75d6f69e'
    options.mqtt = "mqtt://iot.beaconice.cn/"
    options.secret =  "0123456789abcdef"
    thing, err = createBluetoothThing(options)


-- exports.initBluetooth   = initBluetoothUart
-- exports.configBluetooth = setBluetoothConfig
exports.checkButton     = CheckButtonState
exports.createBluetooth = createBluetoothThing

return exports




