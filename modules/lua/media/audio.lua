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
local utils 	= require('utils')
local uv    	= require('uv')
local lmedia 	= require('lmedia')

local laudioin  = lmedia.audio_in
local laudioout = lmedia.audio_out

local TAG = "Camera"

local exports = {}

if (laudioin) then
    exports.MEDIA_FORMAT_AAC = laudioin.MEDIA_FORMAT_AAC
    exports.MEDIA_FORMAT_PCM = laudioin.MEDIA_FORMAT_PCM
end

function exports.openAudioIn(channel, options, callback)
    if (not laudioin) then
        return
    end

    laudioin.init()

    local audioIn = laudioin.open(channel, options)
    if (audioIn == nil) then
        return
    end

    audioIn:start(function(ret, sampleData, sampleTime, flags)
        local sample = {}
        sample.sampleData = sampleData
        sample.sampleTime = sampleTime
        sample.syncPoint  = true
        sample.isAudio    = true

        callback(sample)
    end)

    exports.audioIn = audioIn

    -- 防止 audioIn 对象被系统回收
    local timerId = nil
    timerId = setInterval(2000, function()
        if (not audioIn) then
            clearInterval(timerId)
            timerId = nil
        end
    end)

    return audioIn
end

function exports.openAudioOut(channel, options, callback)
    if (not laudioout) then
        return
    end

	laudioout.init()

    local audioOut = laudioout.open(channel, options)
    if (audioOut == nil) then
        return
    end

    return audioOut
end

return exports
