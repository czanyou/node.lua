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
local fs 	 = require('fs')

local exports = {}

local Watchdog = core.Emitter:extend()
exports.Watchdog = Watchdog

function Watchdog:initialize()
	self.watchdog = -1

end

--[[
 * Turn off the watchdog device.
 * @param flags When flags 1 indicates that the watchdog watchdog is taken back
   by the system, the default is 0.
--]] 
function Watchdog:close(flags)
	if (self.watchdog <= 0) then
		return
	end

	if (flags) then
		fs.writeSync(self.watchdog,-1, 'V');
	end

	fs.closeSync(self.watchdog)
	self.watchdog = -1
end

function Watchdog:feed()
	if (self.watchdog <= 0) then
		return false
	end

	fs.writeSync(self.watchdog,-1, '\0');

	return true
end

-- Turns on and enables the watchdog device.
function Watchdog:open(timeout)
	if (self.watchdog > 0) then
		return
	end

	local deviceName = "/dev/watchdog"
	self.watchdog = fs.openSync(deviceName,'w')

	if (timeout and timeout > 0) then
		self:timeout(timeout)
		self:enable(true)
	end
end

-- Indicates whether the watchdog has been enabled, 
-- or FALSE if the device is not turned on.
function Watchdog:enable(enable)

end

-- Returns the watchdog time-out
function Watchdog:timeout(timeout)

end

return exports
