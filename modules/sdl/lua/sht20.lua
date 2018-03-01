--[[

Copyright 2016 The Node.lua Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

local path 	 = require('path')
local utils  = require('util')
local core 	 = require('core')
local thread = require('thread')
local lsdl   = nil
local li2c   = nil

pcall(function()
  	lsdl   	= require('lsdl')
  	li2c   	= require('lsdl.i2c')
end)


local exports = {}

local function calc_temperature(i2c, data)
	if (type(data) ~= 'string') or (#data < 3) then
		return nil
	end

	--console.printBuffer(data)

	local crc = i2c:crc(data:sub(1, 2))
	assert(crc == data:byte(3))

	local value = data:byte(1)
	value = value << 8
	value = value + data:byte(2)
	value = value & 0xfffc

	-- 
	local temperature = -46.85 + 175.72 * value / 65535
	temperature = math.floor((temperature + 0.05) * 10) / 10
	return temperature
end

local function calc_humidity(i2c, data)
	if (type(data) ~= 'string') or (#data < 3) then
		return nil
	end
	--console.printBuffer(data)

	local crc = i2c:crc(data:sub(1, 2))
	assert(crc == data:byte(3))

	local val = data:byte(1)
	val = val << 8
	val = val + data:byte(2)
	val = val & 0xfffc

	local humidity  = -6 + 125 * val / 65535
	humidity  = math.floor((humidity  + 0.05) * 10) / 10
	return humidity
end

function exports.temperatureAndHumidity(options)
	if (not li2c) then
		return nil, 'Current system does not support the I2C BUS.'
	end

	options = options or {}

	local CMD_SOFT_RESET  	= 0xFE
	local CMD_TEMPERATURE 	= 0xF3
	local CMD_HUMIDITY    	= 0xF5

	local I2C_BUS	  		= options.device or '/dev/i2c-1'
	local I2C_SLAVE   		= 1795
	local I2C_ADDRESS 		= options.address or 0x40 -- SHT21 Address
	local i2c = li2c.open(I2C_BUS)
	if (not i2c) then
		return nil, 'Current system does not support the specified I2C BUS.'
	end

	local nanosleep = lsdl.nanosleep

	local ret, err = i2c:setup(I2C_SLAVE, I2C_ADDRESS)
	if (err) then
		return nil, err
	end

	local ret, err = i2c:write(string.char(CMD_SOFT_RESET)) -- SOFT RESET
	if (err) then
		return nil, err
	end
	
	nanosleep(50)  -- ms

	i2c:write(string.char(CMD_TEMPERATURE)) -- READ Temperature
	nanosleep(200) -- ms

	local ret = i2c:read(3) -- 2 byte value + 1 byte checksum
	local temperature = calc_temperature(i2c, ret)

	i2c:write(string.char(CMD_HUMIDITY)) -- READ humidity 
	nanosleep(120) -- ms

	local ret = i2c:read(3) -- 2 byte value + 1 byte checksum
	local humidity = calc_humidity(i2c, ret)

	i2c:close()

	return temperature, humidity
end

function exports.read(options, callback)
	if (type(options) == 'function') then
		callback = options
		options  = {}
	end

    local _work_func = function (options)
        local  sht20 = require('sdl/sht20')
        return sht20.temperatureAndHumidity(options)
    end

    thread.work(_work_func, callback):queue()
end

return exports
