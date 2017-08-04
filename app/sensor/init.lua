local app       = require('app')
local utils 	= require('utils')
local thread 	= require('thread')
local mqtt 		= require('mqtt')
local path 		= require('path')
local json 		= require('json')
local lpm       = require('ext/lpm')
local conf      = require('ext/conf')
local sensor    = require('device/sht20')
local camera    = require('media/camera')
local fs 		= require('fs')
local data      = require('sqlite3/data')

local exports = {}

-------------------------------------------------------------------------------
-- MQTT publish

local SDCP_DEVICE_ID 	= 'sdcp.device_id'
local SDCP_DEVICE_KEY 	= 'sdcp.device_key'

local function mqtt_publish_data(reported)
    local deviceKey = app.get(SDCP_DEVICE_KEY) or ''
    local deviceId  = app.get(SDCP_DEVICE_ID)  or ''
    
    local options = { deviceKey = deviceKey, deviceId = deviceId }
end

data.dirname = utils.dirname()

-------------------------------------------------------------------------------
--

local query = nil

local function _printInfo(temperature, humidity)
    print('temperature: ' .. tostring(temperature) .. "`C", 
             'humidity: ' .. tostring(humidity) .. "%")
end

local function _onReadTimer()
    sensor.read(function(temperature, humidity)
        if (not temperature) then
            _print(humidity)
            return
        end
        
        _printInfo(temperature, humidity)

        local db = data.open()
        if (db) then
            local interval = 60 * 10

            db:add('temperature', temperature, nil, interval)
            db:add('humidity',    humidity,    nil, interval)

            db:close()
        end

        local data = { temperature = temperature, humidity = humidity }
        mqtt_publish_data(data)
    end)
end

-------------------------------------------------------------------------------
--

function exports.help()
    app.usage(utils.dirname())

    print([[
available command:

- clear
- publish
- start
- status

]])
end

function exports.publish(temperature, humidity)
    local data = { temperature = temperature, humidity = humidity }
    mqtt_publish_data(data) 
end

function exports.status()
    sensor.read(function(temperature, humidity)
        if (not temperature) then
            print(humidity)
            return
        end

        _printInfo(temperature, humidity)
    end)    
end

function exports.clear(...)
    local db = data.open()
    if (db) then
        db:clear()

        db:close()
    end  
end

function exports.start()
    local lockfd = app.tryLock('sensor')
    if (not lockfd) then
        print('The sensor is locked!')
        return
    end

    local interval = 1000 * 60 * 10

    _onReadTimer()
	setInterval(interval, _onReadTimer)
end

function exports.add(stream, value)
    local db = data.open()
    if (db) then
        db:add(stream, value, nil, 60)

        db:close()
    end  
end

function exports.list(...)
    local db = data.open()
    if (db) then
        local ret, count = db:list('temperature'), db:count('temperature')
        console.log('temperature: ', ret, count)

        local ret, count = db:list('humidity'), db:count('humidity')
        console.log('humidity: ', ret, count)

        db:close()
    end   
end

function exports.latest(...)
    local db = data.open()
    if (db) then
        db:init()
        
        local ret = db:latest('temperature')
        console.log('latest temperature: ', ret)

        local ret = db:latest('humidity')
        console.log('latest humidity: ', ret)

        db:close()
    end   
end

function exports.test()
    local db = data.open()
    if (not db) then
        return
    end

    --console.log(db)

    local sql = "SELECT COUNT(*) AS c FROM data"

    sql = "SELECT type,MAX(value) max,AVG(value) avg FROM data GROUP BY type"
  
    local stmt = db:prepare(sql)

    console.time('sql')

    if (stmt) then
        --stmt:bind(name)
        --console.log(stmt:first_cols())

        for row in stmt:rows() do
            console.log(row)
        end

        --print('data_stream_exists: count', count)
        stmt:close()
    end



    db:close()

    console.timeEnd('sql')
end

function exports.stat(...)
    local db = data.open()
    if (not db) then
        return
    end

    print("usage: lpm sensor stat [types, mode, offset]")
    print("  types: ")
    print("  mode: hour, day, week, month, year")
    print("  offset: number")

    console.time('find')

    local stream = {'temperature', 'temperature.min', 'temperature.max'}

    local ret = db:stat('temperature', ...)
    if (not ret) then
        print("no record found!")
        return
    end
    --console.log(ret)

    local grid = app.table({ 16, 10, 10, 10, 10 })

    grid.line()
    grid.cell("Time", "COUNT", "AVG", "MIN", "MAX")
    grid.line()

    for i = 1, #ret do
        local row = ret[i]

        local values = {}
        values[1] = os.date("%m-%d %H:%M", row.startTime)
        values[2] = math.floor(row.count or '0')

        for index = 1, #stream do
            table.insert(values, row[stream[index]] or '-')
        end

        grid.cell(table.unpack(values))
    end
    grid.line()

    db:close()

    console.timeEnd('find')
end

function exports.import()
    local db = data.open()
    if (db) then
        db:init()
        db:import({'temperature', 'humidity'})
        db:close()
    end
end

app(exports)
