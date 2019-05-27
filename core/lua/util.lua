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
meta.name        = "lnode/util"
meta.version     = "1.0.0-4"
meta.license     = "Apache 2"
meta.description = "Wrapper around pretty-print with extra tools for lnode"
meta.tags        = { "lnode", "bind", "adapter" }

local exports = { meta = meta }

local lutils = require('lutils')

local Error  = require('core').Error
local Object = require('core').Object

-- util 模块主要用于支持 Node.lua 内部开发, 也可以用于应用程序和模块开发者.

-------------------------------------------------------------------------------
-- adapt

--[[
    适配器方法
    @param callback {function|thread}
    @param function
    @param args
]]
function exports.adapt(callback, func, ...)
    local nargs = select('#', ...)
    local args = { ... }

    -- No continuation defaults to noop callback
    if not callback then
        callback = exports.noop
    end

    local t = type(callback)
    if t == 'function' then
        args[nargs + 1] = callback
        -- console.printr(args)
        return func(table.unpack(args))

    elseif t ~= 'thread' then
        error("Illegal continuation type " .. t)
    end

    local err, data, waiting
    args[nargs + 1] = function(err, ...)
        if waiting then
            if err then
                coroutine.resume(callback, nil, err)
            else
                coroutine.resume(callback, ...)
            end
        else
            err, data = err and Error:new(err), { ... }
            callback = nil
        end
    end

    func(table.unpack(args))
    if callback then
        waiting = true
        return coroutine.yield(callback)

    elseif err then
        return nil, err

    else
        return table.unpack(data)
    end
end

-- Creates a coroutine to run the specified function
function exports.async(func, ...)
    if (type(func) ~= 'function') then
        return nil, 'Parameter 1 must be a Lua function'
    end

    local thread = coroutine.create(func)
    local ret, err = coroutine.resume(thread, ...)
    if (not ret) then
        return thread, err
    end

    return thread
end

-- 等待指定的方法完成并调用了回调函数, 直接返回回调结果. 这个方法必须在协程中执行
-- @param func 这个函数的最后一个参数必须是一个回调函数, 且一定会被调用.
-- @return 返回回调函数的参数做为结果
function exports.await(func, ...)
    local routine = coroutine.running()

    local ret, waiting, err
    local callback = function(...)
        if (waiting) then
            ret, err = coroutine.resume(routine, ...)
            if (not ret) then
                print(err)
            end

        else
            ret = { ... }
            routine = nil
        end
    end

    local nargs = select('#', ...)
    local args = { ... }
    args[nargs + 1] = callback
    func(table.unpack(args))

    if (routine) then
        waiting = true
        return coroutine.yield(routine)

    else
        return table.unpack(ret)
    end
end

-------------------------------------------------------------------------------
-- bind

-- 为回调函数绑定 self
-- @param fn 要绑定的回调函数
function exports.bind(fn, self, ...)
    assert(fn, "fn is nil")
    local bindArgsLength = select("#", ...)

    -- Simple binding, just inserts self (or one arg or any kind)
    if bindArgsLength == 0 then
        return function(...)
            return fn(self, ...)
        end
    end

    -- More complex binding inserts arbitrary number of args into call.
    local bindArgs = { ... }
    return function(...)
        local argsLength = select("#", ...)
        local args = { ... }
        local arguments = { }
        for i = 1, bindArgsLength do
            arguments[i] = bindArgs[i]
        end

        for i = 1, argsLength do
            arguments[i + bindArgsLength] = args[i]
        end

        return fn(self, table.unpack(arguments, 1, bindArgsLength + argsLength))
    end
end

-------------------------------------------------------------------------------

-- 用来获取当前正在执行的代码源文件所在的目录
-- Indicates the directory where the source file to which the current line
-- of code belongs
function exports.dirname()
    local path = require('path')   
    return path.dirname(exports.filename(3))
end

-- 用来获取当前正在执行的代码源文件的文件名
-- Returns the source file name corresponding to the specified index of the
-- current execution stack
-- @param index If not specified, it indicates the source file where the
--    current line of code is executed
-- @return filename, linenumber
function exports.filename(index)
    local info = debug.getinfo(index or 2, 'Sl') or {}
    -- print(index, console.dump(info))

    local filename = info.source or ''
    if (filename:startsWith("@")) then
        filename = filename:sub(2)
    end
    return filename, info.currentline or -1
end

-------------------------------------------------------------------------------
-- 无操作处理器

function exports.noop(err)
    if err then
        print("Unhandled callback error", err)
    end
end

-------------------------------------------------------------------------------
-- StringBuffer

local StringBuffer = Object:extend()
exports.StringBuffer = StringBuffer

function StringBuffer:initialize(text)
    self.list = {}
    if (text) then
        table.insert(self.list, text)
    end
end

function StringBuffer:append(value)
    if (value) then
        table.insert(self.list, value)
    end

    return self
end

function StringBuffer:toString()
    return table.concat(self.list)
end

_G.StringBuffer = StringBuffer


-------------------------------------------------------------------------------
--

exports.base64Decode    = lutils.base64_decode
exports.base64Encode    = lutils.base64_encode
exports.bin2hex         = lutils.hex_encode
exports.hex2bin         = lutils.hex_decode
exports.md5             = lutils.md5

exports.md5string = function(data)
    return lutils.hex_encode(lutils.md5(data))
end

return exports
