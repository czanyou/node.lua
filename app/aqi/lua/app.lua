local app       = require('app')
local wot       = require('wot')
local express 	= require('express')
local path 		= require('path')
local json  	= require('json')
local util 		= require('util')
local fs    	= require('fs')
local request 	= require('http/request')

local BASE_URL = 'http://service.envicloud.cn:8082'
local ACCESS_KEY = 'Y3PHBNLVDTE1NDM5MTCYMZUZMZA='

BASE_URL = 'http://61.147.166.205:8082'

local dongguan = '101281601';
local beijing  = '101010100';
local shenzhen = '101280601';


local exports = {}

exports.lastAirStatus = {}
exports.lastWeatherStatus = {}
exports.lastDoorStatus = {}
exports.lastAirConditionStatus = {}
exports.lastAirExhaustStatus = {}

function pushDoorRegister(did)
    local point = {
        lock = 1
    };

    local data = { points = { point } }
    pushAirStatus(did, data, function(err, data)
        console.log(did, 'door', err, data)
        if (not err) then
            exports.lastAirStatus[did] = newAirStatus
        end
    end)
end

function pushDoorStatus(did)
    local data = {
        on = true
    }

    pushDataStream(did, 'door.contact', data, function(err, data)
        console.log(did, 'door.contact', err, data)
        if (not err) then
            exports.lastDoorStatus[did] = newAirStatus
        end
    end)
end

function pushAirConditionStatus(did)
    local data = {
        on = true,
        temperature = 25
    }

    pushDataStream(did, 'air.condition', data, function(err, data)
        console.log(did, 'air.condition', err, data)
        if (not err) then
            exports.lastAirConditionStatus[did] = newAirStatus
        end
    end)
end

function pushVentilatorStatus(did)
    local data = {
        on = true
    }

    pushDataStream(did, 'ventilator', data, function(err, data)
        console.log(did, 'ventilator', err, data)
        if (not err) then
            exports.lastAirExhaustStatus[did] = newAirStatus
        end
    end)
end

function onAirStatus(did, newAirStatus)
    local updated = newAirStatus.time
    local lastAirStatus = exports.lastAirStatus[did]
    if (lastAirStatus and lastAirStatus.time == updated) then
        return
    end

    local data = {
        aqi = tonumber(newAirStatus.AQI),
        co = tonumber(newAirStatus.CO),
        no2 = tonumber(newAirStatus.NO2),
        pm10 = tonumber(newAirStatus.PM10),
        pm25 = tonumber(newAirStatus.PM25),
        so2 = tonumber(newAirStatus.SO2),
        o3 = tonumber(newAirStatus.o3),
    }

    pushAirStatus(did, data, function(err, data)
        console.log(did, 'air', err, data)
        if (not err) then
            exports.lastAirStatus[did] = newAirStatus
        end
    end)
end

function onWeatherStatus(did, newAirStatus)
    local updated = newAirStatus.time
    local lastWeatherStatus = exports.lastWeatherStatus[did]
    if (lastWeatherStatus and lastWeatherStatus.time == updated) then
        return
    end

    local data = {
        windspeed = tonumber(newAirStatus.windspeed),
        airpressure = tonumber(newAirStatus.airpressure),
        phenomena = (newAirStatus.phenomena),
        humidity = tonumber(newAirStatus.humidity),
        windpower = (newAirStatus.windpower),
        feelst = tonumber(newAirStatus.feelst),
        winddirect = (newAirStatus.winddirect),
        rain = tonumber(newAirStatus.rain),
        temperature = tonumber(newAirStatus.temperature)
    }

    pushWeatherStatus(did, data, function(err, data)
        console.log(did, 'weather', err, data)
        if (not err) then
            exports.lastWeatherStatus[did] = newAirStatus
        end
    end)
end

local USER_AGENT = 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Mobile Safari/537.36'

function getAirStatus(cityCode, callback)
    local headers = {
        ['User-Agent'] = USER_AGENT
    }

    local options = { headers = headers }

    local urlString = BASE_URL .. '/v2/cityairlive/' .. ACCESS_KEY .. '/' .. cityCode
    request.get(urlString, options, function(err, response, body) 
        if (err) then
            callback(err);
            return
        end

        local data = json.parse(body)
        callback(nil, data);
    end)
end

function getWeatherStatus(cityCode, callback)
    local headers = {
        ['User-Agent'] = USER_AGENT
    }

    local options = { headers = headers }

    local urlString = BASE_URL .. '/v2/weatherlive/' .. ACCESS_KEY .. '/' .. cityCode
    request.get(urlString, options, function(err, response, body) 
        if (err) then
            callback(err);
            return
        end

        local data = json.parse(body)
        callback(nil, data);
    end)
end

function pushDataStream(did, name, data, callback)
    local message = {
        did = did,
        type = 'stream',
        data = data
    }

    local messageData = json.stringify(message)
    local headers = {
        ['Content-Type'] = 'application/json'
    }
    
    local options = { data = messageData, headers = headers }

    local urlString = 'http://iot.beaconice.cn/v2/stream/messages/'
    -- local urlString = 'http://localhost:8951/messages/'
    request.post(urlString, options, function(err, response, body) 
        if (err) then
            callback(err)
            return
        end

        local result = json.parse(body)
        callback(nil, result)
    end)

end

function pushAirStatus(did, data, callback)
    pushDataStream(did, 'air', data, callback)
end

function pushWeatherStatus(did, data, callback)
    pushDataStream(did, 'weather', data, callback)
end

function exports.query()
    getWeatherStatus(beijing, function(err, data)
        console.log(err, data)
    end)

    getWeatherStatus(shenzhen, function(err, data)
        console.log(err, data)
    end)

    getWeatherStatus(dongguan, function(err, data)
        console.log(err, data)
    end)

    getAirStatus(beijing, function(err, data)
        console.log(err, data)
    end)

    getAirStatus(shenzhen, function(err, data)
        console.log(err, data)
    end)

    getAirStatus(dongguan, function(err, data)
        console.log(err, data)
    end)
end

function exports.push()
    local mac = 'fff101010100'

    local jsonData = {
        AQI = '49',
        CO = '0.28',
        NO2 = '9.58',
        PM10 = '52',
        PM25 = '8',
        SO2 = '2.67',
        citycode = '101010100',
        o3 = '59.42',
        primary = '无',
        rcode = 200,
        rdesc = 'Success',
        time = '2018120417'
    }

    local data = {
        aqi = tonumber(jsonData.AQI),
        co = tonumber(jsonData.CO),
        no2 = tonumber(jsonData.NO2),
        pm10 = tonumber(jsonData.PM10),
        pm25 = tonumber(jsonData.PM25),
        so2 = tonumber(jsonData.SO2),
        o3 = tonumber(jsonData.o3),
    }

    pushAirStatus(mac, data, function(err, data)
        console.log(err, data)
    end)
end

function updateCityDataStream(cityCode)
    
    getAirStatus(cityCode, function(err, data)
        if (not err) and (data) then
            local did = 'fff' .. cityCode;
            onAirStatus(did, data)
        end
    end)
end

function updateDataStream()
    updateCityDataStream(shenzhen);
    updateCityDataStream(beijing);
    updateCityDataStream(dongguan);
end

function exports.start()
    local interval = 1000 * 60;
    setInterval(interval, function()
        updateDataStream();
    end)

    updateDataStream();


    local interval = 1000 * 60;
    setInterval(interval, function()
        exports.test();
    end)

    exports.test();
end

function exports.test()
    local did = '112233445520';
    pushDoorStatus(did);

    local did = '112233445569';
    pushAirConditionStatus(did);

    local did = '001122334455';
    pushVentilatorStatus(did);
end

function exports.run()

end

app(exports)
