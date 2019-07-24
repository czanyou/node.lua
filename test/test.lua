local path = require('path')
local fs = require('fs')
local uv     = require('luv')
local wot = require('wot')
-- local test = require('./test1')
-- local log = require('./log')

local uart_recevie_buf ={}
local sensor_info = {}
local sensor_list = {}

local text = [[
    ds
    dfsd
    sdfasdf
    sda
]]

-- local tmp_file = '/tmp/test'
local tmp_file = '/dev/ttyAMA1'
-- fs.writeFileSync(tmp_file, text)

local options = {
    flags = 'r',
    mode = '0644',
    chunk_size = 65536,
    offset = 16,
    fd = nil,
    length = nil,
}

local function onEnd()
    print('end')
end



function hex2str(hex,size)

	--拼接字符串
	local index=1
	local ret=""
	for index=1,size do
		ret=ret..string.format("%02X",hex:sub(index):byte())
	end
 
	return ret
end

local  boardcast_analyze 
-- local function onData(data)
--     print('data', data)    
--     -- sensor_info.did = "12345"
--     -- sensor_info.temperature = 26.13
--     -- sensor_info.humiture = 70
--     -- sensor_list[sensor_info.did] = sensor_info

--     -- for k, v in pairs(sensor_list) do
--     --     print(k)
--     --     for k,v in pairs(v) do
--     --         print(k..":"..v)
--     --     end
--     -- end
-- end

-- local function open(callback)
--     local fp = fs.createReadStream(tmp_file, options)
--     fp:once('end', onEnd)
--     fp:on('data', callback)

--     print("lua test");
--     return fp
-- end

-- open(onData)
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
    local function data_analysis(size,data)

        if(size > 0)
        then
            local index = 11
            while(index <= 11+size-2)
            do


                local chunk_size = data[index]
                local chunk_type = data[index+1]
                local frame_type = data[index+4]

                

                if(chunk_type == 0x16 and frame_type == 0xa1 and chunk_size == 16)
                then                
                    sensor_info.did =mac
                    sensor_info.temperature = data[index+7]+data[index+8]*0.01
                    sensor_info.humidity = data[index+9]+data[index+10]*0.01
                    print("temperature:\t"..sensor_info.temperature.."\t".."humidity:\t"..sensor_info.humidity)

                    thing:sendStream(sensor_info)


   
                end
                index = index+chunk_size+1
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
                -- print(pos.."\t".."ret"..#ret)
                size = string.byte(ret,pos+2) | string.byte(ret,pos+3)<<8
                if(size == nill)
                then
                    print("size error")
                end
                
            else
                break

            end
            
            if(pos and size and #ret and pos+size+3 <= #ret)
            then
                -- print("pos"..pos.."\tsize"..size.."\tret"..#ret)
                local crc = string.byte(ret,pos+size-2+3+1) | string.byte(ret,pos+size-2+3+2)<<8

                
                
                local analysis_data = string.sub(ret,pos+4,pos+size+3)
                -- boardcast_analyze(analysis_data)
                -- console.printBuffer(analysis_data)   
                for i=1,size+4,1 do
                    data[i] = string.byte(ret,pos+i-1)
                end

                mac = string.format("%02x%02x%02x%02x%02x%02x",data[5],data[6],data[7],data[8],data[9],data[10])
                
                -- console.printBuffer(ret)
                if(string_nocase_cmp("ac233fa05271",mac))
                then
                    
                    -- for i=1,size+4,1 do
                    --     print("data"..i.."\t"..string.format("%02x",data[i]))
                    -- end
                   
                    data_analysis(size,data)


                end
                ret = string.sub(ret,pos+size+4,#ret)
                -- console.printBuffer(ret)
            else
                break
            end
        else
            break
        end
    until(0)

    end
    

end


local modbus = require('lmodbus')

console.log(modbus.version())
local dev = modbus.new("/dev/ttyAMA1", 9600, 78, 8, 1)    -- N: 78, O: 79, E: 69

console.log(dev)

dev:connect()
fd = dev:uart_fd()
dev:uart_write("123165")
print("fd"..fd)
uart = uv.new_poll(fd)
uv.poll_start(uart, "rw", uart_recevie_callback)


-- dev:close()



boardcast_analyze = function(ret)
    console.printBuffer(ret)   
    -- for i=1,#data,1 do
    --     data[i] = string.byte(ret,1)
    --     print("data"..i.."\t"..string.format("%02x",data[i]))
    -- end
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

 

    -- register
    webThing:expose()

    webThing:on('register', function(response)
        local result = response and response.result
        if (result and result.code and result.error) then
            console.log('register', 'error', response.did, result)

        elseif (result.token) then
            console.log('register', response.did, result.token)
        end
    end)

    return webThing

end

-- local options={}

-- options.did = '1231231'
-- options.mqtt = "mqtt://iot.beaconice.cn/"
-- options.secret =  "5c25b29e8ca1712897c805c0"

-- -- console.log(options);

-- thing, err = createBluetoothThing(options)



return {createThing = createBluetoothThing}



