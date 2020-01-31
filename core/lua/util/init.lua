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
-- async

-- Creates a coroutine to run the specified function
---@param func function
function exports.async(func, ...)
    if (type(func) ~= 'function') then
        return nil, 'Parameter 1 must be a Lua function'
    end

    local thread = coroutine.create(func)
    local success, err = coroutine.resume(thread, ...)
    if (not success) then
        return thread, err
    end

    return thread
end

-- 等待指定的方法完成并调用了回调函数, 直接返回回调结果. 这个方法必须在协程中执行
---@param func function 这个函数的最后一个参数必须是一个回调函数, 且一定会被调用.
---@return any 返回回调函数的参数做为结果
function exports.await(func, ...)
    local routine = coroutine.running()

    local result, waiting

    local nargs = select('#', ...)
    local args = { ... }
    args[nargs + 1] = function(...)
        if (waiting) then
            local success, err = coroutine.resume(routine, ...)
            if (not success) then
                print(err)
            end

        else
            result = { ... }
            routine = nil
        end
    end

    func(table.unpack(args))

    if (routine) then
        waiting = true
        return coroutine.yield(routine)

    else
        return table.unpack(result)
    end
end

function exports.promisify(original)
    local Promise = require('promise')
    return function(...)
        local promise = Promise.new()
        local success, error = pcall(original, ..., function(err, ...)
            if (err ~= nil) then
                promise:reject(err)
            else
                promise:resolve(...)
            end
        end)

        if (not success) then
            promise:reject(error or 'error')
        end

        return promise
    end
end

-------------------------------------------------------------------------------
-- bind

-- 为回调函数绑定 self
-- @param {function} fn 要绑定的回调函数
-- @param {object} self 要绑定的 self 对象
-- @param {...} ... 要绑定的更多参数
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

    local offset = 3
    local pathname = path.dirname(exports.filename(offset))
    if (not pathname) then
        return pathname

    elseif (pathname:startsWith('/')) then
        return pathname

    else
        return path.join(process.cwd(), pathname)
    end
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
exports.base16Decode    = lutils.hex_decode
exports.base16Encode    = lutils.hex_encode
exports.hexDecode       = lutils.hex_decode
exports.hexEncode       = lutils.hex_encode
exports.bin2hex         = lutils.hex_encode
exports.hex2bin         = lutils.hex_decode
exports.md5             = lutils.md5
exports.sha1            = lutils.sha1
exports.crc32           = lutils.crc32
exports.crc16           = lutils.crc16

exports.md5string = function(data)
    return lutils.hex_encode(lutils.md5(data))
end

exports.sha1string = function(data)
    return lutils.hex_encode(lutils.sha1(data))
end

-------------------------------------------------------------------------------
--

local KBYTES = 1024
local MBYTES = 1024 * 1024
local GBYTES = 1024 * 1024 * 1024
local TBYTES = 1024 * 1024 * 1024 * 1024

exports.format = string.format

-- Format the bytes number to human-readable string
function exports.formatBytes(bytes)
    bytes = tonumber(bytes)
    if (not bytes) then
        return
    end

    local unit = ''
    local scale = 1
    if (bytes < KBYTES) then
        return bytes .. ""

    elseif (bytes < MBYTES) then
        unit = 'K'
        scale = KBYTES

    elseif (bytes < GBYTES) then
        unit = 'M'
        scale = MBYTES

    elseif (bytes < TBYTES) then
        unit = 'G'
        scale = GBYTES

    else
        unit = 'T'
        scale = TBYTES
    end

    local value = (math.floor((bytes / scale) * 10 + 0.5) / 10)
    local a, b = math.modf(value)
    if (b > 0) then
        return value .. unit
    else
        return a .. unit
    end
end

function exports.formatNumber(value)
    value = tonumber(value)
    if (not value) then
        return
    end

    local a, b = math.modf(value)
    if (b > 0) then
        return value
    else
        return a
    end
end

-- Format the floating-point number
function exports.formatFloat(value, size)
    value = tonumber(value)
    if (not value) then
        return
    end

    return string.format("%." .. (size or 1) .. "f", value)
end

function exports.formatTable(data, columns)
    local cols = {}
    local rows = {}
    local output = {}

    for col, name in ipairs(columns) do
        cols[col] = #name
    end

    for index, item in ipairs(data) do
        local row = {}

        for col, name in ipairs(columns) do
            local value = tostring(item[name])
            row[col] = value

            if (value) then
                local count = cols[col] or 0
                if (count < #value) then
                    cols[col] = #value
                end
            end
        end

        rows[index] = row
    end

    for col, name in ipairs(columns) do
        cols[col] = (cols[col] or 0) + 3
    end

    local formatLine = function(ch)
        ch = ch or '-'

        for i = 1, #cols do
            local count = math.max(0, cols[i] - 2)
            output[#output + 1] = ' '
            output[#output + 1] = string.rep(ch, count)
        end

        table.insert(output, '\n')
    end

    local formatCell = function(values)
        for i = 1, #cols do
            local colWidth = cols[i] - 2
            local value = tostring(values[i])
            output[#output + 1] = ' '
            output[#output + 1] = string.padRight(value, colWidth, colWidth)
        end

        table.insert(output, '\n')
    end

    formatCell(columns)
    formatLine()

    for index, row in ipairs(rows) do
        formatCell(row)
    end
    print()

    return table.concat(output)
end

function exports.clone(data)
    local function copy(org, res)
        for k, v in pairs(org) do
            local valueType =  type(v)
            if valueType ~= "table" then
                res[k] = v;

            else
                res[k] = {};
                copy(v, res[k])
            end
        end
    end

    if (type(data) ~= "table") then
        return data
    end

    local result = {}
    copy(data, result)
    return result
end

function exports.keys(data)
    if (type(data) ~= "table") then
        return data
    end

    local result = {}
    for k, v in pairs(data) do
        table.insert(result, k)
    end
    return result
end

function exports.diff(table1, table2)
    table1 = table1 or {}
    table2 = table2 or {}

    local sub
    local result
    for key, value2 in pairs(table2) do
        local value1 = table1[key]
        if (value1 ~= value2) then
            if (not result) then
                result = {}
            end

            result[key] = value2
        end
    end

    for key, value1 in pairs(table1) do
        local value2 = table2[key]
        if (value2 == nil) then
            if (not sub) then
                sub = {}
            end

            sub[key] = value1
        end
    end

    return result, sub
end

function exports.size(data)
    local valueType = type(data)
    if (valueType == 'string') then
        return #data
    elseif (valueType == 'table') then
        local count = 0
        for k, v in pairs(data) do
            count = count + 1
        end
        return count

    elseif (data ~= nil) then
        return 1
    else
        return 0
    end
end

return exports
