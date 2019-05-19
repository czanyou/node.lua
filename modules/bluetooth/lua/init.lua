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
local uv 	     = require('luv')
local core 	     = require('core')

local exports = {}

local BluetoothDevice = core.Emitter:extend()

function BluetoothDevice:initialize(options)
    -- If advertisments were activated using BluetoothDevice.watchAdvertisements().
    self.watchingAdvertisements = false

    -- open ble device
	local device = lbluetooth.open()
    if (not device) then
        self:emit('error', 'Can`t open the bluetooth device')
        return nil
    end

    local info = device:get_info() or {}
    --console.log(device:get_info())

    self.id = info.deviceId
    self.name = info.name
    self.address = info.address

    self.device = device
end

-- Starts watching for advertisments.
function BluetoothDevice:watchAdvertisements()
    local device = self.device
    if (not device) then
        return
    end

    if (self.watchingAdvertisements) then
        return
    end

    -- start scan
    local ret = device:scan(function(data)
        self:emit('data', data)
    end)

    if (ret ~= 0) then
        self:emit('error', 'Can`t open bluetooth scan')
        return nil
    end

    self.watchingAdvertisements = true
end

-- Stops watching for advertisments.
function BluetoothDevice:unwatchAdvertisements()
    if (self.device) then
        self.device:stop()
        self.device = nil
    end

    self.watchingAdvertisements = false
end

function BluetoothDevice:close()
    if (self.device) then
        self.device:close()
        self.device = nil
    end

    self.watchingAdvertisements = false
end

-- request a BluetoothDevice object with the specified options.
function exports.requestDevice(options, callback)
    if (type(options) == 'function') then
        callback = options
        options = nil
    end

    local device = BluetoothDevice:new(options)
    if (callback) then
        callback(nil, device)
    end
end

return exports
