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
local core 		= require('core')
local fs 		= require('fs')
local path  	= require('path')
local utils 	= require('utils')

local session 	= require('media/session')

local exports = {}

--[[

Represents a media source

]]

-------------------------------------------------------------------------------
-- MediaSource

local MediaSource = core.Emitter:extend()
exports.MediaSource = MediaSource

function MediaSource:initialize(cameraId, options)
	if (not options) then
		options = {}
	end

	self.mediaSessions = {}
	self.name 			= options.name
	self.pathname 		= options.pathname
	self.sessionSeq 	= 1
	self.isStopped		= false
end

function MediaSource:close()
	local count = #self.mediaSessions
	for i = 1, count do
		local mediaSession = self.mediaSessions[i]
		mediaSession:close()
	end

	self.mediaSessions  = {}
	self.isStopped		= true
end

function MediaSource:newMediaSession(options)
	local mediaSession = session.newMediaSession(options)

	table.insert(self.mediaSessions, mediaSession)

	mediaSession.id = self.sessionSeq

	self.sessionSeq = self.sessionSeq + 1
	return mediaSession
end

function MediaSource:removeMediaSession(mediaSession)
	local count = #self.mediaSessions
	for i = 1, count do
		if (self.mediaSessions[i] == mediaSession) then
			table.remove(self.mediaSessions, i)
			break
		end
	end
end

function MediaSource:writeSample(sampleData, sampleTime, flags)
	local sessions = nil

	local count = #self.mediaSessions
	for i = 1, count do
		local mediaSession = self.mediaSessions[i]
		if (not mediaSession) then

		elseif (mediaSession.isStopped) then
			if (not sessions) then
				sessions = {}
			end

			table.insert(sessions, mediaSession)
		else

			mediaSession:writePacket(sampleData, sampleTime, flags)
		end
	end

	if (sessions) then
		local count = #sessions
		for i = 1, count do
			self:removeMediaSession(sessions[i])
		end
	end
end

function exports.newMediaSource(options)
	return MediaSource:new(options)
end

return exports
