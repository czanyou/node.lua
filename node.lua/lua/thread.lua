--[[

Copyright 2014 The Luvit Authors. All Rights Reserved.
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

--- lnode thread management

local meta = { }
meta.name        = "lnode/thread"
meta.version     = "0.1.2"
meta.license     = "Apache 2"
meta.description = "thread module for lnode"
meta.tags        = { "lnode", "thread", "threadpool", "work" }

local exports = { meta = meta }

local uv = require('uv')
local Object = require('core').Object

-------------------------------------------------------------------------------
--- lnode thread

exports.equal = uv.thread_equal

exports.join  = uv.thread_join

exports.self  = uv.thread_self

exports.sleep = uv.sleep

function exports.start(thread_func, ...)
    local dumped = thread_func
    if (type(thread_func) == 'function') then
        dumped = string.dump(thread_func)
    end
    
    -- print('dumped:' .. dumped)
    local _thread_entry = function(dumped, ...)
        pcall(require, 'init')

        -- Run function with require injected
        local fn = load(dumped)
        if (fn) then
            fn(...)
        end

        -- Start new event loop for thread.
        local uv = require('uv')
        uv.run()
        uv.loop_close()
    end

    return uv.new_thread(_thread_entry, dumped, ...)
end

-------------------------------------------------------------------------------
--- lnode threadpool

local Worker = Object:extend()

function Worker:queue(...)
    uv.queue_work(self.handler, self.dumped, ...)
end

function exports.work(thread_func, callback)
    local worker = Worker:new()
    worker.dumped = type(thread_func) == 'function'
        and string.dump(thread_func) or thread_func

    local function _thread_func(dumped, ...)
        if not _G._uv_works then
            _G._uv_works = { }
        end

        pcall(require, 'init')

        -- try to find cached function entry
        local fn
        if not _G._uv_works[dumped] then
            fn = load(dumped)

            -- cache it
            _G._uv_works[dumped] = fn
            
        else
            fn = _G._uv_works[dumped]
        end
        -- Run function

        return fn(...)
    end

    if type(callback) ~= 'function' then
        callback = function() end
    end

    worker.handler = uv.new_work(_thread_func, callback)
    return worker
end

function exports.queue(worker, ...)
    worker:queue(...)
end

return exports
