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
local uv = require('uv')

local meta = { }
meta.name           = "lnode/init"
meta.version        = "0.1.2"
meta.license        = "Apache 2"
meta.description    = "init module for lnode"
meta.tags           = { "lnode", "init" }

local exports = { meta = meta }

-------------------------------------------------------------------------------
-- Bundle module loader

local function bundleSearcher(name)
    local miniz = require('miniz')

    if (type(name) ~= 'string') then
        return nil
    end

    local bundle_reader = function (filename)
        if (not _G._miniz_readers) then
            _G._miniz_readers = { }
        end

        local reader = _G._miniz_readers[filename]
        if (not reader) then
            reader = miniz.new_reader(filename)
            if (reader) then
                _G._miniz_readers[filename] = reader
            end
        end

        return reader
    end

    local load_bundle_module = function (filename, name)
        if (type(name) ~= 'string') then
            return

        elseif (type(filename) ~= 'string') then
            return
        end

        local reader = bundle_reader(filename)
        if (reader == nil) then
            return
        end

        local path =  'lib/' .. name .. '.lua'
        local index, err = reader:locate_file(path)
        if (not index) then
            path = 'lib/' .. name .. '/init.lua'
            index, err = reader:locate_file(path)
            if (not index) then
                return
            end
        end

        if (reader:is_directory(index)) then
            return
        end

        local data = reader:extract(index)
        if (data) then
             return load(data)
        end
    end

    local load_bundle_file = function (libname, subpath)
        local filename = package.searchpath(libname, package.cpath)
        if (filename) then
            return load_bundle_module(filename, subpath)
        end
    end

    local ret = load_bundle_file('lnode', name)
    if (ret) then
        return ret
    end

    local index = name:find('/')
    if (index) then
        local libname = name:sub(1, index - 1)
        local subpath = name:sub(index + 1)
        return load_bundle_file(libname, subpath)
    end

    return nil
end

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

    local lnode = require('lnode')
    local path  = require('path')
    local fs    = require('fs')

    local basePath = lnode.NODE_LUA_ROOT
    if (not basePath) then
        return nil
    end

    if (not fs.existsSync(path.join(basePath, 'modules'))) then
        basePath = path.dirname(basePath)
    end
    if (not basePath) then
        return nil
    end

    local filename;

    --console.log(basePath)
    local index = name:find('/')
    if (index) then
        local libname = name:sub(1, index - 1)
        local subpath = name:sub(index + 1)

        filename = path.join(basePath, 'modules', libname, 'lua', subpath .. ".lua")

    else
        filename = path.join(basePath, 'modules', name, 'lua', "init.lua")
    end

    if (not fs.existsSync(filename)) then
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

    local lnode = require('lnode')
    local path  = require('path')
    local fs    = require('fs')

    local basePath = lnode.NODE_LUA_ROOT
    if (not basePath) then
        return nil
    end

    if (not fs.existsSync(path.join(basePath, 'app'))) then
        basePath = path.dirname(basePath)
    end

    if (not basePath) then
        return nil
    end

    local filename

    --console.log(basePath)
    local index = name:find('/')
    if (index) then
        local libname = name:sub(1, index - 1)
        local subpath = name:sub(index + 1)

        filename = path.join(basePath, 'app', libname, 'lua', subpath .. ".lua")

    else
        filename = path.join(basePath, 'app', name, 'lua', "init.lua")
    end

    --console.log('filename', filename)

    if (not fs.existsSync(filename)) then
        return nil
    end

    local ret, err = loadfile(filename)
    if (err) then print(err); os.exit() end
    return ret, err
end

package.searchers[5] = localSearcher
package.searchers[6] = bundleSearcher
package.searchers[7] = moduleSearcher
package.searchers[8] = appSearcher

-------------------------------------------------------------------------------
-- run loop

if (not _G.run_loop) then
    _G.run_loop = function(mode)
        uv.run(mode)
        uv.loop_close()
    end

    _G.runLoop = _G.run_loop
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
