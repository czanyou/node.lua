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
local core 	 = require('core')
local fs 	 = require('fs')

local join = path.join

local exports = {}

-------------------------------------------------------------------------------
-- 

local function sanitizePinNumber(pinNumber)
	if (not isnumber(pinNumber)) then
		return nil, ("Pin number isn't valid");
	end

	return tonumber(pinNumber, 10);
end

local function sanitizeDirection(direction)
	direction = (direction or "").toLowerCase():trim();
	if (direction == "in" or direction == "input") then
		return "in";
	elseif (direction == "out" or direction == "output" or not direction) then
		return "out";
	else 
		return nil, ("Direction must be 'input' or 'output'");
	end
end

-------------------------------------------------------------------------------
-- GPIO

local GPIO = core.Emitter:extend()
exports.GPIO = GPIO

function GPIO:initialize(pin, options)
	self.sysFsPath 	= '/sys/class/gpio'
	self.pin 		= tonumber(pin)


end

function GPIO:close(callback)
	if (not self.pin) then 
		return 
	end

	fs.writeFile(join(self.sysFsPath, 'unexport'), self.pin, callback)
end

function GPIO:direction(direction, callback)
	if (not self.pin) then 
		return 
	end

	-- direction(callback)
	if (type(direction) == 'function') then
		callback  = direction
		direction = nil
	end

	if (not callback) then
		callback = function() end
	end

	local name = 'gpio' .. tostring(self.pin)
	local filename = join(self.sysFsPath, name, 'direction')
	if (direction) then
		fs.writeFile(filename, direction, callback);

	else
		fs.readFile(filename, function(err, data)
			if (err) then
				callback(err)
				return
			end

			callback(nil, data)
		end)
	end
end

function GPIO:open(callback)
	if (not self.pin) then 
		return 
	end	

	fs.writeFile(join(self.sysFsPath, 'export'), self.pin, callback)
end

function GPIO:read(callback)
	if (not self.pin) then 
		return 
	end

	if (not callback) then
		callback = function() end
	end

	local name = 'gpio' .. tostring(self.pin)
	local filename = join(self.sysFsPath, name, 'value')
	fs.readFile(filename, function(err, data)
		if (err) then
			callback(err)
			return
		end

		callback(nil, tonumber(data))
	end)
end

function GPIO:write(value, callback)
	if (not self.pin) then 
		return 
	end

	value = tonumber(value)
	if (value) and (value ~= 0) then
		value = 1
	else
		value = 0
	end

	local name = 'gpio' .. tostring(self.pin)
	local filename = path.join(self.sysFsPath, name, 'value')
	fs.writeFile(filename, tostring(value), callback);
end

-------------------------------------------------------------------------------
-- exports

function exports.gpio(pin, options)
	return GPIO:new(pin, options)
end

setmetatable(exports, {
	__call = function(self, ...)
		return self.gpio(...)
	end
})

return exports

