local utils = require('util')
local path 	= require('path')
local conf  = require('app/conf')
local json  = require('json')
local fs    = require('fs')
local httpd = require('httpd')

local data  = require('./../lua/data')

local thread = require('thread')
local querystring = require('querystring')

data.dirname = path.dirname(utils.dirname())

local function asyncReadSensor(callback)
    local function _work_func()
        local sensor = require('sdl/sht20')
        return sensor.temperatureAndHumidity()
    end

    thread.queue(thread.work(_work_func, callback))
end

local function on_sensor_status(request, response)
    asyncReadSensor(function(temperature, humidity)
        local status = {}
        status.temperature  = temperature or '-'
        status.humidity     = humidity    or '-'
        response:json(status)
    end)
end

local function get_hygrothermograph_state(request, response)
	asyncReadSensor(function(temperature, humidity)
        local describe = {}
		describe.version = 1
		describe.type = 'Hygrothermograph:1'

		local serviceStateTable = {}
		describe.serviceStateTable = serviceStateTable

        local state = {}
        state.name 	= 'Temperature'
        state.value = temperature or '0'
        serviceStateTable[1] = state

        state = {}
        state.name 	= 'Humidity'
        state.value = humidity    or '0'
        serviceStateTable[2] = state

	    state = {}
        state.name 	= 'TemperatureUnit'
        state.value = 'Centigrade'
        serviceStateTable[3] = state   
             
        response:json(describe)
    end)
end

local function get_hygrothermograph_describe(list, labels)
	local describe = {}
	describe.version = 1
	describe.type = 'Hygrothermograph:1'

	local serviceStateTable = {}
	describe.serviceStateTable = serviceStateTable

	local state = {}
	serviceStateTable[1] = state
	state.type = 'TemperatureUnit'
	state.name = 'string'
	state.allowed = {"Centigrade","Fahrenheit"}

	state = {}
	serviceStateTable[2] = state
	state.type = 'Temperature'
	state.name = 'number'

	state = {}
	serviceStateTable[3] = state
	state.type = 'Humidity'
	state.name = 'number'	

	return describe
end

local function on_sensor_chart(request, response)
    local query = request.query

    local mode    = query.mode or 'month' -- day,week,month,year
    local offset  = query.offset or 0
    local stream  = query.type or 'temperature' -- stream type

    local options = {}

    local content = data.query(stream, mode, offset, options)
    response:json(content)

    --response:send(content, 'image/svg+xml')
end

local methods = {}
methods['/chart']   = on_sensor_chart
methods['/status']  = on_sensor_status

httpd.call(methods, request, response)

return true
