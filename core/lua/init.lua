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
local uv = require('luv')

local meta = { }
meta.name           = "lnode/init"
meta.version        = "0.1.2"
meta.license        = "Apache 2"
meta.description    = "init module for lnode"
meta.tags           = { "lnode", "init" }

local exports = { meta = meta }

-------------------------------------------------------------------------------
-- module loader

local function localSearcher(name)
    if (type(name) ~= 'string') then
        return nil
    end

    local _get_script_filename = function()
        --console.trace()

        local waitRequire = false
        local filename = nil
        local currentline = nil

        for i = 1, 10 do
            local info = debug.getinfo(i, nil, 'Sln')
            if (not info) then
                return
            end

            if (info.name == 'require') then
                waitRequire = true

            elseif (waitRequire) then
                filename = info.source or ''
                currentline = info.currentline
                break
            end
        end

        -- [[
        --local info = debug.getinfo(4, 'Sl') or {}
        --local filename = info.source or ''
        if (filename:startsWith("@")) then
            filename = filename:sub(2)
        end
        return filename, currentline or -1
    end

    local load_local_file = function(name)
        local basePath = _get_script_filename()
        if (not basePath) then
            return nil
        end

        local path = require('path')
        basePath = path.dirname(basePath)

        local filename = path.join(basePath, name .. ".lua")

        local ret, err = loadfile(filename)
        if (err) then print(err); os.exit() end
        return ret, err
    end

    if (name:byte(1) == 46) then -- startsWith: `.`
        return load_local_file(name)
    end
end

local function moduleSearcher(name)
    if (type(name) ~= 'string') then
        return nil
    end

    if (name == 'lnode') then
        return nil
    end

    local lnode = require('lnode')
    local basePath = lnode.NODE_LUA_ROOT
    if (not basePath) then
        return nil
    end

    local stat, err = uv.fs_stat(basePath .. '/modules')
    if (stat == nil) then
        basePath = basePath .. '/../'
    end

    local filename;

    --console.log(basePath)
    local index = name:find('/')
    if (index) then
        local libname = name:sub(1, index - 1)
        local subpath = name:sub(index + 1)

        filename = (basePath .. '/modules/' .. libname .. '/lua/' .. subpath .. ".lua")

    else
        filename = (basePath .. '/modules/' .. name .. '/lua/' .. "init.lua")
    end

    local stat, err = uv.fs_stat(filename)
    if (stat == nil) then
        return nil
    end

    local ret, err = loadfile(filename)
    if (err) then print(err); os.exit() end
    return ret
end

local function appSearcher(name)
    if (type(name) ~= 'string') then
        return nil
    end

    if (name == 'lnode' or name == 'path' or name == 'fs') then
        return nil
    end

    local lnode = require('lnode')
    if (lnode == nil) then
        return
    end

    local basePath = lnode.NODE_LUA_ROOT
    if (not basePath) then
        return nil
    end

    local stat, err = uv.fs_stat(basePath .. '/app')
    if (stat == nil) then
        basePath = basePath .. '/../'
    end

    local filename

    --console.log(basePath)
    local index = name:find('/')
    if (index) then
        local libname = name:sub(1, index - 1)
        local subpath = name:sub(index + 1)

        filename = (basePath .. '/app/' .. libname .. '/lua/' .. subpath .. ".lua")

    else
        filename = (basePath .. '/app/' .. name .. '/lua/' .. "init.lua")
    end

    --console.log('filename', filename)
    local stat, err = uv.fs_stat(filename)
    if (stat == nil) then
        return nil
    end

    local ret, err = loadfile(filename)
    if (err) then print(err); os.exit() end
    return ret, err
end

package.searchers[7] = appSearcher
package.searchers[6] = moduleSearcher
package.searchers[5] = package.searchers[4]
package.searchers[4] = package.searchers[3]
package.searchers[3] = package.searchers[2]
package.searchers[2] = package.searchers[1]
package.searchers[1] = localSearcher

-------------------------------------------------------------------------------
-- run loop

if (not _G.runLoop) then
    _G.runLoop = function(mode)
        uv.run(mode)
        uv.loop_close()
    end
end

-------------------------------------------------------------------------------
-- process

-- 默认导入 process 模块

if (not _G.process) then
    _G.process = require("process")
end

-------------------------------------------------------------------------------
-- console

-- 默认导入 console 模块

if (not _G.console) then
    _G.console = require("console")
end

-------------------------------------------------------------------------------
-- Date

local Date = {}

Date.now = function() 
    local sec, usec = uv.gettimeofday()
    return sec * 1000 + math.floor(usec / 1000)
end

function Date:new(time)
    local date = {}
    
    function date:setTime(time)
        self.time = time or Date.now()
        self.value = os.date("*t", math.floor(self.time / 1000))
    end

    function date:setDate(day)
        self.value.day = day
        self:setTime(os.time(self.value) * 1000 + self:getMilliseconds())
    end

    function date:setMonth(month)
        self.value.month = month
        self:setTime(os.time(self.value) * 1000 + self:getMilliseconds())
    end

    function date:setYear(year)
        self.value.year = year
        self:setTime(os.time(self.value) * 1000 + self:getMilliseconds())
    end

    function date:setHours(hour)
        self.value.hour = hour
        self:setTime(os.time(self.value) * 1000 + self:getMilliseconds())
    end

    function date:setMinutes(min)
        self.value.min = min
        self:setTime(os.time(self.value) * 1000 + self:getMilliseconds())
    end

    function date:setSeconds(sec)
        self.value.sec = sec
        self:setTime(os.time(self.value) * 1000 + self:getMilliseconds())
    end

    function date:setMilliseconds(milliSeconds)
        self.time = math.floor(self.time / 1000) * 1000 + milliSeconds
    end

    function date:getTime()
        return self.time
    end

    function date:toString()
        return os.date("%c", math.floor(self.time / 1000))
    end

    function date:toDateString()
        return os.date("%F", math.floor(self.time / 1000))
    end

    function date:toTimeString()
        return os.date("%T", math.floor(self.time / 1000))
    end

    function date:toISOString()
        local msec = self:getMilliseconds() .. 'Z'
        return os.date("!%FT%T", math.floor(self.time / 1000)) .. "." .. msec:padLeft(4, 4, '0');
    end

    function date:getDay()
        return self.value.wday - 1
    end

    function date:getDate()
        return self.value.day
    end

    function date:getMonth()
        return self.value.month
    end

    function date:getYear()
        return self.value.year
    end

    function date:getHours()
        return self.value.hour
    end

    function date:getMinutes()
        return self.value.min
    end

    function date:getSeconds()
        return self.value.sec
    end

    function date:getMilliseconds()
        return self.time % 1000
    end
    
    date:setTime(time)
    return date
end

if (not _G.Date) then
    _G.Date = Date
end

-------------------------------------------------------------------------------
-- searcher

--[[
package._searcher = package.searchers[1]
package.searchers[1] = function(name)
    print('_searcher', name)
    return package._searcher(name)
end
--]]

-------------------------------------------------------------------------------
-- require

--[[
_G._require = require
_G.require = function(...)
    print('require', ...)
    return _require(...)
end
--]]

-------------------------------------------------------------------------------
-- timer

-- 类似 Node.js 默认就导入 `timer` 模块的主要几个方法

local timer = nil

local _loadTimer = function()
    if (not timer) then
        timer = require('timer')
    end
    return timer
end

function _G.clearImmediate(timeoutObject)
    _loadTimer()
    return timer.clearImmediate(timeoutObject)
end

function _G.clearInterval(intervalObject)
    _loadTimer()
    return timer.clearInterval(intervalObject)
end

function _G.clearTimeout(timeoutObject)
    _loadTimer()
    return timer.clearTimeout(timeoutObject)
end

function _G.setImmediate(callback, ...)
    _loadTimer()
    return timer.setImmediate(callback, ...)
end

function _G.setInterval(delay, callback, ...)
    _loadTimer()
    return timer.setInterval(delay, callback, ...)
end

function _G.setTimeout(delay, callback, ...)
    _loadTimer()
    return timer.setTimeout(delay, callback, ...)
end

return exports
