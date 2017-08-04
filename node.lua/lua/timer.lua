--[[

Copyright 2014-2015 The Luvit Authors. All Rights Reserved.
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
local meta = { }
meta.name        = "lnode/timer"
meta.version     = "1.0.0-4"
meta.license     = "Apache 2"
meta.description = "Javascript style setTimeout and setInterval for lnode"
meta.tags        = { "lnode", "timer" }

local exports = { meta = meta }

local uv = require('uv')

local Object = require('core').Object
local bind   = require('utils').bind

-------------------------------------------------------------------------------
--- Timer

local Timer = Object:extend()

function Timer:initialize()
    self._handle = uv.new_timer()
    self._active = false
end

function Timer:_update()
    self._active = uv.is_active(self._handle)
end

-- Timer:start(timeout, interval, callback)
function Timer:start(timeout, interval, callback)
    uv.timer_start(self._handle, timeout, interval, callback)
    self:_update()
end

-- Timer:stop()
function Timer:stop()
    uv.timer_stop(self._handle)
    self:_update()
end

-- Timer:again()
function Timer:again()
    uv.timer_again(self._handle)
    self:_update()
end

-- Timer:close()
function Timer:close()
    uv.close(self._handle)
    self:_update()
end

-- Timer:setRepeat(interval)
Timer.setRepeat = uv.timer_set_repeat

-- Timer:getRepeat()
Timer.getRepeat = uv.timer_get_repeat

-- Timer.now
Timer.now = uv.now

------------------------------------------------------------------------------

function exports.sleep(delay, thread)
    thread = thread or coroutine.running()
    uv.new_timer():start(delay, 0, function()
        return assert(coroutine.resume(thread))
    end )
    return coroutine.yield()
end

------------------------------------------------------------------------------

--[[
To schedule execution of a one-time callback after delay milliseconds. Returns 
a timeoutObject for possible use with clearTimeout(). Optionally you can also 
pass arguments to the callback.

It is important to note that your callback will probably not be called in exactly 
delay milliseconds - Node.js makes no guarantees about the exact timing of when 
the callback will fire, nor of the ordering things will fire in. The callback 
will be called as close as possible to the time specified.
--]]
function exports.setTimeout(delay, callback, ...)
    local timer = uv.new_timer()
    local args = { ...}
    uv.timer_start(timer, delay, 0, function()
        uv.timer_stop(timer)
        uv.close(timer)
        callback(table.unpack(args))
    end )
    return timer
end

--[[
To schedule the repeated execution of callback every delay milliseconds. Returns 
a intervalObject for possible use with clearInterval(). Optionally you can also 
pass arguments to the callback.
--]]
function exports.setInterval(interval, callback, ...)
    local timer = uv.new_timer()
    uv.timer_start(timer, interval, interval, bind(callback, ...))
    return timer
end

--[[
Stops an interval from triggering.
--]]
function exports.clearInterval(timer)
    if uv.is_closing(timer) then return end
    uv.timer_stop(timer)
    uv.close(timer)
end

exports.clearTimeout = exports.clearInterval

------------------------------------------------------------------------------

local checker = uv.new_check()
local idler   = uv.new_idle()

local immediateQueue = { }

local function _onCheck()
    local queue = immediateQueue
    immediateQueue = { }
    for i = 1, #queue do
        queue[i]()
    end

    -- If the queue is still empty, we processed them all
    -- Turn the check hooks back off.
    if #immediateQueue == 0 then
        if (checker) then
            checker:stop()
        end

        if (idler) then
            idler:stop()
        end
    end
end

--[[
To schedule the "immediate" execution of callback after I/O events callbacks 
and before setTimeout and setInterval . Returns an immediateObject for possible 
use with clearImmediate(). Optionally you can also pass arguments to the callback.

Callbacks for immediates are queued in the order in which they were created. 
The entire callback queue is processed every event loop iteration. If you queue 
an immediate from inside an executing callback, that immediate won't fire until 
the next event loop iteration.
--]]
function exports.setImmediate(callback, ...)
    -- If the queue was empty, the check hooks were disabled.
    -- Turn them back on.
    
    if #immediateQueue == 0 then
        local pprint  = require('utils').pprint

        if (not uv.is_closing(checker)) then
            checker:start(_onCheck)
        end

        if (not uv.is_closing(idler)) then
            idler:start(_onCheck)
        end
    end

    immediateQueue[#immediateQueue + 1] = bind(callback, ...)
end

------------------------------------------------------------------------------

local lists = { }

local function list_init(list)
    list._idleNext = list
    list._idlePrev = list
end

local function list_peek(list)
    if list._idlePrev == list then
        return nil
    end
    return list._idlePrev
end

local function list_remove(item)
    if item._idleNext then
        item._idleNext._idlePrev = item._idlePrev
    end

    if item._idlePrev then
        item._idlePrev._idleNext = item._idleNext
    end

    item._idleNext = nil
    item._idlePrev = nil
end

local function list_append(list, item)
    list_remove(item)
    item._idleNext = list._idleNext
    list._idleNext._idlePrev = item
    item._idlePrev = list
    list._idleNext = item
end

local function list_is_empty(list)
    return list._idleNext == list
end

local list_expiration
list_expiration = function(timer, msecs)
    return function()
        local now = Timer.now()
        while list_peek(timer) do
            local elem = list_peek(timer)
            local diff = now - elem._idleStart;
            if ((diff + 1) < msecs) == true then
                timer:start(msecs - diff, 0, list_expiration(timer, msecs))
                return
            else
                list_remove(elem)
                if elem.emit then
                    elem:emit('timeout')
                end
            end
        end

        -- Remove the timer if it wasn't already
        -- removed by unenroll
        local list = lists[msecs]
        if list and list_is_empty(list) then
            list:stop()
            list:close()
            lists[msecs] = nil
        end
    end
end

local function list_insert(item, msecs)
    item._idleStart = Timer.now()
    item._idleTimeout = msecs

    if msecs < 0 then return end

    local list

    if lists[msecs] then
        list = lists[msecs]
    else
        list = Timer:new()
        list_init(list)
        list:start(msecs, 0, list_expiration(list, msecs))
        lists[msecs] = list
    end

    list_append(list, item)
end

local function list_unenroll(item)
    list_remove(item)
    local list = lists[item._idleTimeout]
    if list and list_is_empty(list) then
        -- empty list
        list:stop()
        list:close()
        lists[item._idleTimeout] = nil
    end
    item._idleTimeout = -1
end

exports.unenroll = list_unenroll

-- does not start the timer, just initializes the item
exports.enroll = function(item, msecs)
    if item._idleNext then
        list_unenroll(item)
    end
    item._idleTimeout = msecs
    list_init(item)
end

-- call this whenever the item is active (not idle)
exports.active = function(item)
    local msecs = item._idleTimeout
    if msecs and msecs >= 0 then
        local list = lists[msecs]
        if not list or list_is_empty(list) then
            list_insert(item, msecs)
        else
            item._idleStart = Timer.now()
            list_append(lists[msecs], item)
        end
    end
end

exports.now = uv.now

return exports
