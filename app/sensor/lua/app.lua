local app       = require('app')
local utils 	= require('util')
local thread 	= require('thread')
local path 		= require('path')
local json 		= require('json')
local conf      = require('app/conf')
local sensor    = require('sdl/sht20')
local fs 		= require('fs')

local data      = require('./data')

local exports = {}


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
            local interval = 60 * 5

            db:add('temperature', temperature, nil, interval)
            db:add('humidity',    humidity,    nil, interval)

            db:close()
        end
    end)
end

-------------------------------------------------------------------------------
--

function exports.help()
    app.usage(utils.dirname())

    print([[
available command:

- clear
- start
- status
- stat
- info

]])
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

    print("usage: lpm sensor stat [mode, offset]")
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

    print("Total Count:", #ret)

    console.timeEnd('find')
end

function exports.query(...)
    local db = data.open()
    if (not db) then
        return
    end

    print("usage: lpm sensor stat [mode, offset]")
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

    for i = 1, #ret do
        local row = ret[i]
        row.avg = math.floor(row.avg * 100) / 100
        row.start = nil
    end

    console.log(json.stringify(ret))

    db:close()

    print("Total Count:", #ret)

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

function exports.info()
    local db = data.open()
    if (not db) then
        return
    end

    console.time('info')

    local streamType = 'temperature'

    print('Total Count:', db:count(streamType))

    local latest = db:latest(streamType)
    --console.log(latest)
    print("Latest: ", latest.date, latest.value)
  
    console.timeEnd('info')
    db:close()
end

app(exports)
