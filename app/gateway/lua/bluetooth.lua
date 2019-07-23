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

-- local uart_recevie_buf ={}

local sensor_list = {}
local white_list = {}

local dataReady = 0

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

local test = {
    0x31,
    0x32,
    0x33,
    0x34,
    0x35,
    0x36,
    0x02,
    0x01,
    0x06,
    0x0E,
    0xFF,
    0x0D,
    0x06,
    0x11,
    0x02,
    0x02,
    0x20,
    0x0A,
    0x03,
    0x1A,
    0x04,
    0x00,
    0x00
}

local function array2string(array, len)
    local ret
    ret = string.char(array[1])
    for i = 2, len do
        ret = ret .. string.char(array[i])
    end
    return ret
end

local boardcast_analyze

local thing

function Sleep(n)
    os.execute("sleep " .. n)
end

local function onread(data)
    print(data)
end

local function string_nocase_cmp(src, dest)
    return string.find(string.lower(src), string.lower(dest))
end

local timer

local function uart_recevie_callback()
    local function boardcast_analysis(packet_data)
        local packet_type = 0x00
        local data = {}
        local size = #packet_data
        local i
        local flag = 0
        for i = 1, size do
            data[i] = string.byte(packet_data, i)
        end
        local rssi = data[size] - 256
        local mac = string.format("%02x%02x%02x%02x%02x%02x", data[1], data[2], data[3], data[4], data[5], data[6])
        console.log(mac, rssi)
        for  k, v in ipairs(white_list) do
            if(string.find(v,mac) ~= nill)
            then
                flag = 1
                break
            end
        end

        if(flag == 1 and size > 0)
        then
            if(timer) then
                clearTimeout(timer)
            end
            dataReady = 1
            timer = setTimeout(5000,function()
                dataReady = 0
            end)
            flag = 0
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

                end
                if(chunk_type == 0xff)
                then
                    local frame_type = data[index+5]
                end

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

                            sensor_info.pressure = (data[index+sensor_index+1]*65536 +data[index+sensor_index+2]*256+data[index+sensor_index+3])/100
                            sensor_index = sensor_index+4

                        else
                            console.log(string.format("null:%02x",sensor_type))
                            break
                        end
                    end
                    sensor_info.rssi = rssi

                    app.bluetoothDevices[mac]:sendStream(sensor_info)
                    console.log(sensor_info)

                end

                index = index+chunk_size+1

            end
        end
    end

    local function config_analysis(packet_data)
        console.log("config_analysis")
    end

    local function slave_analysis(packet_data)
        console.log("slave_analysis")
    end

    local function rowdata_analysis(packet_data)
        local channel = string.byte(packet_data, 1)
        local code = string.byte(packet_data, 4)
        local seq_t = string.byte(packet_data, 5)
        local size = string.byte(packet_data, 2) | string.byte(packet_data, 3) << 8
        if (size >= 4) then
            local analysis_data = string.sub(packet_data, 4, 5 + size - 4)

            if (channel == 0xff) then
                
                boardcast_analysis(analysis_data)
                
            elseif (channel == 0x00) then
                -- console.log("channel = 00")
                -- console.printBuffer(analysis_data)
                if (code == 0x0a) then
                    if(size <= 4) then
                        setBluetoothConfig(0x01, "scan=,0D0611")
                    end
                    
                else
                    config_analysis(analysis_data)
                end
            -- else
            --     if(code == 0x0a  )
            --     then
            --         console.log(analysis_data);
            --     else
            --         slave_analysis(analysis_data)
            --     end
            end
        end
    end



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
                            
                            rowdata_analysis(analysis_data)
                        end
                        -- console.log("before")
                        -- console.printBuffer(ret)
                        ret = string.sub(ret,pos+size+4,#ret)
                        -- console.log("after")
                        -- console.printBuffer(ret)
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
end



local function initBluetoothUart()
    local dev = modbus.new("/dev/ttyAMA2", 115200, 78, 8, 1) -- N: 78, O: 79, E: 69
    dev:connect()
    fd = dev:uart_fd()
    uart = uv.new_poll(fd)
    uv.poll_start(uart, "r", uart_recevie_callback)


end


local flag = 0

local function createBluetoothThing(options)
    local webThing = {}
    if (not options) then
        return nil, "need options"
    elseif (not options.mqtt) then
        return nil, "need MQTT url option"
    elseif (not options.did) then
        return nil, "need did option"
    end
    table.insert(white_list, options.did)
    local bluetooth = {
        id = options.did,
        url = options.mqtt,
        name = options.name or "bluetooth",
        actions = {},
        properties = {},
        events = {}
    }
    console.log(bluetooth)
    webThing = wot.produce(bluetooth)
    webThing.secret = options.secret

    webThing:expose()

    webThing:on(
        "register",
        function(response)
            local result = response and response.result
            if (result and result.code and result.error) then
                console.log("register", "error", response.did, result)
            elseif (result.token) then
                console.log("register", response.did, result.token)
            end
        end
    )

    console.log(white_list)
    if (flag == 0) then
        flag = 1
        initBluetoothUart()
        setBluetoothConfig(0x01, "scan=,0D0611")
        setInterval(100*60, function()
            console.log("test")
            setBluetoothConfig(0x01, "scan")
        end)
    end
    return webThing
end

function exports.dataStatus()
    return dataReady
end

exports.createBluetooth = createBluetoothThing

return exports
