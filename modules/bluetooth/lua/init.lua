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
local lbluetooth = require('lbluetooth')
local fs  		 = require('fs')
local uv 	     = require('uv')

local exports = {}

local ble_poll = nil

local function start_le_scan(options)
     local callback = exports.callback

    -- open ble device
	local device = lbluetooth.open()
    if (not device) then
        if (callback) then
            callback('Could not open device')
        end
        return nil
    end

    -- start scan
    local ret = device:scan(function(data)
        if (callback) then
            callback(nil, data)
        end
    end)

    if (ret ~= 0) then
        if (callback) then
            callback('Could not start scan')
        end

        device:close()
        return nil, ret
    end

    return device
end

-- Start the scan
function exports.scan(options, callback)
    -- function(callback)
    if (type(options) == 'function') then
        callback = options; 
        options = nil
    end

    options = options or {}
    exports.callback = callback

    if (exports.lbluetooth) then
        return 0
    end

    local device, ret = start_le_scan(options)
    exports.lbluetooth = device

    return ret
end

-- Stop scanning and turn off the associated Bluetooth device
function exports.stop()
    if (exports.lbluetooth) then
        exports.lbluetooth:close()
        exports.lbluetooth = nil
    end
end

return exports
