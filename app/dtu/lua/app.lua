local app       = require('app')
local wot       = require('wot')
local express 	= require('express')
local path 		= require('path')
local json  	= require('json')
local util 		= require('util')
local fs    	= require('fs')
local request 	= require('http/request')

local exports = {}

function getMacAddress()
    local faces = os.networkInterfaces()
    if (faces == nil) then
    	return
    end

	local list = {}
    for k, v in pairs(faces) do
        if (k == 'lo') then
            goto continue
        end

        for _, item in ipairs(v) do
            if (item.family == 'inet') then
                list[#list + 1] = item
            end
        end

        ::continue::
    end

    if (#list <= 0) then
    	return
    end

    local item = list[1]
    if (not item.mac) then
    	return
    end

    return util.bin2hex(item.mac)
end

function exports.start()
    exports.register()
end

function exports.register()
    local did = getMacAddress();
    did = 'AA0001000601'
    local gateway = { id = did }

    local thing = wot.produce(gateway)
    thing:addAction('bind', {

    }, function(input) 
        console.log('test', 'input', input)
        local promise = Promise.new()

        setTimeout(0, function()
            promise:resolve('100000')
        end)

        return promise
    end)

    thing:addProperty('config', {

    })

    local url = "mqtt://iot.beaconice.cn/"
    local client = wot.register(url, thing)
    client:on('register', function(ret)
        console.log(ret)
    end)

    setInterval(1000 * 600, function()
        -- 采集器
        local streams = {
            on = true
        }
        client:sendStream(streams)

        -- 温湿度传感器
        streams = {
            temperature = getRandomNumber(20, 20),
            humidity = getRandomNumber(60, 65)
        }
        client:sendStream(streams, { did = 'aa0001000501' })

        sendMeterValues(client);
        sendMotroValue(client);        
    end)

    setInterval(1000 * 600, function()
        local x = fft();
        local y = fft();
        local z = fft();
        local streams = {
            sampleRate = 2000,
            mode = 1,
            x = x,
            y = y,
            z = z
        }
        client:sendStream(streams, { did = 'aa0001000401' })
    end)

    setInterval(1000 * 600, function()
        sendPHValue(client);
    end)

    setTimeout(1000, function()
        sendMotroValue(client);
        sendMeterValues(client);
        sendPHValue(client);
    end);
end

function sendMeterValues(client)
    sendMeterValue(client, 'aa0001000201');

    sendMeterValue(client, 'aa0001000411');
    sendMeterValue(client, 'aa0001000412');
    sendMeterValue(client, 'aa0001000413');

    sendMeterValue4(client, 'aa0001000424');
    sendMeterValue5(client, 'aa0001000425');
    sendMeterValue6(client, 'aa0001000426');
end

function sendMotorValues(client)
    sendMotroValue(client, 'aa0001000301');
end

function sendMotroValue(client, did)
    local streams = {
        temperature = getRandomNumber(40, 43),
        rotateSpeed = getRandomNumber(10000, 10010)
    }
    client:sendStream(streams, { did = did })
end

function getRandomNumber(min, max) 
    return math.floor(math.random(min * 10, max * 10)) / 10;
end

function sendMeterValue(client, did)
    local streams = {
        powerFactor = 1,
        activePower = 1.38,
        activeEnergy = 10.8,
        apparentPower = 1.38,
        reactivePower = 0,
        voltage_a = getRandomNumber(232, 235),
        electricity_a = getRandomNumber(3, 5),
        voltage_b = getRandomNumber(232, 235),
        electricity_b = getRandomNumber(4, 5),
        voltage_c = getRandomNumber(232, 235),     
        electricity_c = getRandomNumber(4, 5)
    }
    client:sendStream(streams, { did = did })
end

function sendMeterValue4(client, did)
    local activePower = 22.24
    local streams = {
        powerFactor = 0.95,
        activePower = activePower,
        activeEnergy = 96741.602,
        apparentPower = activePower,
        reactivePower = 7.92,
        voltage_a = getRandomNumber(380, 383),
        electricity_a = getRandomNumber(38, 39),
        voltage_b = getRandomNumber(381, 383),
        electricity_b = getRandomNumber(39, 40),
        voltage_c = getRandomNumber(381, 384),     
        electricity_c = getRandomNumber(39, 41)
    }
    client:sendStream(streams, { did = did })
end

function sendMeterValue5(client, did)

    local activePower = 21.24
    local streams = {
        powerFactor = 0.94,
        activePower = activePower,
        activeEnergy = 10242.0,
        apparentPower = activePower,
        reactivePower = 7.92,
        voltage_a = getRandomNumber(380, 383),
        electricity_a = getRandomNumber(38, 39),
        voltage_b = getRandomNumber(381, 383),
        electricity_b = getRandomNumber(39, 40),
        voltage_c = getRandomNumber(381, 384),     
        electricity_c = getRandomNumber(39, 41)
    }
    client:sendStream(streams, { did = did })
end

function sendMeterValue6(client, did)

    local activePower = 12.65
    local streams = {
        powerFactor = 1,
        activePower = activePower,
        activeEnergy = 51547.0,
        apparentPower = activePower,
        reactivePower = 0.5,
        voltage_a = getRandomNumber(380, 383),
        electricity_a = getRandomNumber(24, 25),
        voltage_b = getRandomNumber(381, 383),
        electricity_b = getRandomNumber(26, 27),
        voltage_c = getRandomNumber(381, 384),     
        electricity_c = getRandomNumber(27, 28)
    }
    client:sendStream(streams, { did = did })
end

function sendPHValue(client)
    local streams = {
        ph = math.floor(math.random(7, 8))
    }
    client:sendStream(streams, { did = 'aa0001001101' })
end

function fft()
    local text = ''
    for i = 1, 512 do
        local data = math.floor(math.random(0, 255))
        text = text .. string.char(data)
    end

    -- console.log(data)
    return util.base64Encode(text)
end

function exports.test() 
    local data = {};
    local text = ''
    for i = 1, 512 do
        data[i] = math.floor(math.random(0, 255))
        text = text .. string.char(data[i])
    end

    -- console.log(data)
    console.log(text)
    console.log(util.base64Encode(text))
end

app(exports)
