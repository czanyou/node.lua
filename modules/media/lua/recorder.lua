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

local core  	= require('core')
local lwriter 	= require('lts.writer')
local fs    	= require('fs')

local exports = {}

local MediaRecorder = core.Emitter:extend()
exports.MediaRecorder = MediaRecorder

function MediaRecorder:initialize(options)

    self.totalBytes = 0
    self._writer = 0

    options = options or {}

    local filename = options.filename

    local stream = fs.createWriteStream(filename)

    local writer = lwriter.new()
    writer:start(function(sampleData, sampleTime, flags)
        stream:write(sampleData)
        self.totalBytes = self.totalBytes + #sampleData
    end)

    self._writer = writer
end

function MediaRecorder:close()
	local writer = self._writer
	self._writer = nil

	if (writer) then
		writer:close()
	end
end

function MediaRecorder:write(sample)
    local writer = self._writer
    self._writer = nil
    
	if (sample.syncPoint) then
        writer:writeSyncInfo(sample.sampleTime)
    end

    writer:write(sample.sampleData, sample.sampleTime, true)
end

function exports.openRecorder(options, callback)
	local recorder = MediaRecorder:new(options, callback)

	return recorder
end

return exports
