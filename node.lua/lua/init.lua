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
    
    local _filename = function()
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
        local basePath = _filename()
        if (not basePath) then
            return nil
        end

        local path = require('path')
        basePath = path.dirname(basePath)

        local filename = path.join(basePath, name .. ".lua")
        --print('_filename', filename)
        return loadfile(filename)
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

    --_print('bundleLoader', name, name:byte(1))
    -- 如果是相对目录
    if (name:byte(1) == 46) then -- startsWith: `.`
        return load_local_file(name)
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

package.searchers[5] = bundleSearcher

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
