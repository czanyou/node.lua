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

--[[
This module is for various classes and utilities that don't need their own
module.
]]
local meta = { }
meta.name        = "lnode/core"
meta.version     = "1.0.7"
meta.license     = "Apache 2"
meta.description = "Core object model for lnode using simple prototypes and inheritance."
meta.tags        = { "lnode", "objects", "inheritance" }

local exports = { meta = meta }

-------------------------------------------------------------------------------
-- String 兼容 Javascript 扩展
-- ~~~~~~~~~~~

-- 把字符串分割为字符串数组。
-- @param separator 必需。字符串或正则表达式，从该参数指定的地方分割 text
-- String.split() 执行的操作与 Array.join 执行的操作是相反的
--
function string.split(text, separator)  
    local startIndex = 1
    local splitIndex = 1
    local array = {}
    if (not separator) then
        separator = ' '
    end
    
    while true do
        local lastIndex = string.find(text, separator, startIndex, true)
        if not lastIndex then
            array[splitIndex] = string.sub(text, startIndex, string.len(text))
            break
        end

        array[splitIndex] = string.sub(text, startIndex, lastIndex - 1)
        startIndex = lastIndex + string.len(separator)
        splitIndex = splitIndex + 1
    end

    return array
end

-- 返回字符串的长度
function string.length(text)
    return #text
end

-- 返回首尾不包含空白字符的字符串
function string.trim(text)
    return string.gsub(text, "^%s*(.-)%s*$", "%1")
end

-- 指出是否以 find 开始
function string.startsWith(text, find)
    return not not string.find(text, '^'..find)
end

-- 指出是否以 find 结束
function string.endsWith(text, find)
    return not not string.find(text, find .. '$')
end

-- 为指定的文本尾部添加占位空白, 方便对齐显示
function string.padRight(text, min, max)
    if (type(text) ~= 'string') then
        text = tostring(text)
    end
    
    local len = #text
    if (max and len > max) then
        return text:sub(1, max)
    end

    if (len < min) then
        return text .. string.rep(' ', min - len)
    end

    return text
end

function string.padLeft(text, min, max)
    if (type(text) ~= 'string') then
        text = tostring(text)
    end

    local len = #text
    if (max and len > max) then
        return text:sub(1, max)
    end

    if (len < min) then
        return string.rep(' ', min - len) .. text
    end

    return text
end


-------------------------------------------------------------------------------

--[[
Returns whether obj is instance of class or not.

    local object = Object:new()
    local emitter = Emitter:new()

    assert(instanceof(object, Object))
    assert(not instanceof(object, Emitter))

    assert(instanceof(emitter, Object))
    assert(instanceof(emitter, Emitter))

    assert(not instanceof(2, Object))
    assert(not instanceof('a', Object))
    assert(not instanceof({}, Object))
    assert(not instanceof(function() end, Object))

Caveats: This function returns true for classes.
    assert(instanceof(Object, Object))
    assert(instanceof(Emitter, Object))
]]
function exports.instanceof(obj, class)
    if type(obj) ~= 'table' or obj.meta == nil or not class then
        return false
    end

    if obj.meta.__index == class then
        return true
    end

    local meta = obj.meta
    while meta do
        if meta.super == class then
            return true

        elseif meta.super == nil then
            return false
        end

        meta = meta.super.meta
    end
    return false
end

-------------------------------------------------------------------------------

--[[
This is the most basic object in Node.lua. It provides simple prototypal
inheritance and inheritable constructors. All other objects inherit from this.
]]
local Object = { }

exports.Object = Object

Object.meta = { __index = Object }

-- Create a new instance of this object
function Object:create()
    local meta = rawget(self, "meta")
    if not meta then 
        error("Cannot inherit from instance object") 
    end

    return setmetatable( { }, meta)
end

--[[
Creates a new instance and calls `obj:initialize(...)` if it exists.

    local Rectangle = Object:extend()
    function Rectangle:initialize(w, h)
      self.w = w
      self.h = h
    end
    function Rectangle:getArea()
      return self.w * self.h
    end
    local rect = Rectangle:new(3, 4)
    p(rect:getArea())
]]
function Object:new(...)
    local instance = self:create()
    if type(instance.initialize) == "function" then
        instance:initialize(...)
    end
    return instance
end

--[[
Creates a new sub-class.

    local Square = Rectangle:extend()
    function Square:initialize(w)
      self.w = w
      self.h = h
    end
]]

function Object:extend()
    local subclass = self:create()
    local meta = { }
    -- move the meta methods defined in our ancestors meta into our own
    -- to preserve expected behavior in children (like __tostring, __add, etc)
    for k, v in pairs(self.meta) do
        meta[k] = v
    end
    meta.__index = subclass
    meta.super = self
    subclass.meta = meta
    return subclass
end

-------------------------------------------------------------------------------

--[[
This class can be used directly whenever an event emitter is needed.

    local emitter = Emitter:new()
    emitter:on('foo', p)
    emitter:emit('foo', 1, 2, 3)

Also it can easily be sub-classed.

    local Custom = Emitter:extend()
    local c = Custom:new()
    c:on('bar', onBar)

Unlike EventEmitter in node.js, Emitter class doesn't auto binds `self`
reference. This means, if a callback handler is expecting a `self` reference,
utils.bind() should be used, and the callback handler should have a `self` at
the beginning its parameter list.

    function some_func(self, a, b, c)
    end
    emitter:on('end', utils.bind(some_func, emitter))
    emitter:emit('end', 'a', 'b', 'c')
]]
local Emitter = Object:extend()
exports.Emitter = Emitter

-- By default, any error events that are not listened for should throw errors
function Emitter:missingHandlerType(name, ...)
    if name == "error" then

        -- error(tostring(args[1]))
        -- we define catchall error handler
        if self ~= process then
            -- if process has an error handler
            local handlers = rawget(process, "handlers")
            if handlers and handlers["error"] then
                -- delegate to process error handler
                process:emit("error", ..., self)
            end
        end
    end
end

local EmitterOnceMeta = { }

function EmitterOnceMeta:__call(...)
    self.emitter:removeListener(self.name, self)
    return self.callback(...)
end

-- Same as `Emitter:on` except it de-registers itself after the first event.
function Emitter:once(name, callback)
    return self:on(name, setmetatable( {
        emitter  = self,
        name     = name,
        callback = callback
    } , EmitterOnceMeta))
end

-- Adds an event listener (`callback`) for the named event `name`.
function Emitter:on(name, callback)
    local handlers = rawget(self, "handlers")
    if not handlers then
        handlers = { }
        rawset(self, "handlers", handlers)
    end

    local handlers_for_type = rawget(handlers, name)
    if not handlers_for_type then
        if self.addHandlerType then
            self:addHandlerType(name)
        end
        handlers_for_type = { }
        rawset(handlers, name, handlers_for_type)
    end

    table.insert(handlers_for_type, callback)
    return self
end

function Emitter:listenerCount(name)
    local handlers = rawget(self, "handlers")
    if not handlers then
        return 0
    end

    local handlers_for_type = rawget(handlers, name)
    if not handlers_for_type then
        return 0
    else
        local count = 0
        for i = 1, #handlers_for_type do
            if handlers_for_type[i] then
                count = count + 1
            end
        end
        return count
    end
end

-- Emit a named event to all listeners with optional data argument(s).
function Emitter:emit(name, ...)
    local handlers = rawget(self, "handlers")
    if not handlers then
        self:missingHandlerType(name, ...)
        return
    end

    local handlers_for_type = rawget(handlers, name)
    if not handlers_for_type then
        self:missingHandlerType(name, ...)
        return
    end

    for i = 1, #handlers_for_type do
        local handler = handlers_for_type[i]
        if handler then handler(...) end
    end

    for i = #handlers_for_type, 1, -1 do
        if not handlers_for_type[i] then
            table.remove(handlers_for_type, i)
        end
    end
    return self
end

-- Remove a listener so that it no longer catches events.
function Emitter:removeListener(name, callback)
    local handlers = rawget(self, "handlers")
    if not handlers then return end
    local handlers_for_type = rawget(handlers, name)
    if not handlers_for_type then return end
    if callback then
        for i = #handlers_for_type, 1, -1 do
            local h = handlers_for_type[i]
            if type(h) == "function" then
                h = h == callback
            elseif type(h) == "table" then
                h = h == callback or h.callback == callback
            end
            if h then
                handlers_for_type[i] = false
            end
        end
    else
        for i = #handlers_for_type, 1, -1 do
            handlers_for_type[i] = false
        end
    end
end

-- Remove all listeners
--  @param {String?} name optional event name
function Emitter:removeAllListeners(name)
    local handlers = rawget(self, "handlers")
    if not handlers then return end
    local handlers_for_type = rawget(handlers, name)
    if handlers_for_type then
        for i = #handlers_for_type, 1, -1 do
            handlers_for_type[i] = false
        end
    else
        rawset(self, "handlers", { })
    end
end

-- Get listeners
--  @param {String} name event name
function Emitter:listeners(name)
    local handlers = rawget(self, "handlers")
    if not handlers then
        return { }
    end
    
    local handlers_for_type = rawget(handlers, name)
    if not handlers_for_type then
        return { }
    else
        return handlers_for_type
    end
end

--[[
Utility that binds the named method `self[name]` for use as a callback.  The
first argument (`err`) is re-routed to the "error" event instead.

    local Joystick = Emitter:extend()
    function Joystick:initialize(device)
      self:wrap("onOpen")
      FS.open(device, self.onOpen)
    end

    function Joystick:onOpen(fd)
      -- and so forth
    end
]]
function Emitter:wrap(name)
    local fn = self[name]
    self[name] = function(err, ...)
        if (err) then return self:emit("error", err) end
        return fn(self, ...)
    end
end

-- Propagate the event to another emitter.
function Emitter:propagate(eventName, target)
    if (target and target.emit) then
        self:on(eventName, function(...) target:emit(eventName, ...) end)
        return target
    end

    return self
end

-------------------------------------------------------------------------------
-- Error

-- This is for code that wants structured error messages.
local Error = Object:extend()
exports.Error = Error

-- Make errors tostringable
function Error.meta.__tostring(table)
    return table.message
end

function Error:initialize(message)
    self.message = message
    if message then
        self.code = tonumber(message:match('([^:]+): '))
    end
end

-------------------------------------------------------------------------------
-- os

local uv     = require('uv')
local lutils = require('lutils')

-- A constant defining the appropriate End-of-line marker for the operating system.
local function _getEndOfLine()
    local platform = lutils.os_platform()
    if (platform == 'win32') then
        return '\r\n'
    else 
        return '\n'
    end
end

if (not uv.os_tmpdir) then
    uv.os_tmpdir = uv.os_homedir
end

local function noop()

end

os.arch               = lutils.os_arch          -- operating system CPU architecture. Possible values are 'x64', 'arm' and 'ia32'. value of process.arch.
os.cpus               = uv.cpu_info             -- Returns an array of objects containing information about each CPU/core
os.endianness         = nil                     -- endianness of the CPU. Possible values are 'BE' for big endian or 'LE' for little endian.
os.EOL                = _getEndOfLine()         -- A constant defining the appropriate End-of-line marker for the operating system.
os.freemem            = uv.get_free_memory      -- amount of free system memory in bytes.
os.homedir            = uv.os_homedir           -- home directory of the current user.
os.hostname           = uv.os_gethostname or noop -- hostname of the operating system.
os.loadavg            = uv.loadavg              -- Returns an array containing the 1, 5, and 15 minute load averages.
os.networkInterfaces  = uv.interface_addresses  -- Get a list of network interfaces:
os.platform           = lutils.os_platform      -- operating system platform. Possible values are 'darwin', 'freebsd', 'linux', 'sunos' or 'win32'. value of process.platform.
os.release            = nil                     -- operating system release.
os.tmpdir             = uv.os_tmpdir()          -- operating system's default directory for temporary files.
os.totalmem           = uv.get_total_memory     -- total amount of system memory in bytes.
os.type               = lutils.os_platform      -- operating system name.
os.uptime             = uv.uptime               -- system uptime in seconds.

os.getppid            = uv.os_getppid
os.getpid             = uv.os_getpid
os.ifname             = uv.if_indextoname
os.ifid               = uv.if_indextoiid

os.setenv             = uv.os_setenv
os.unsetenv           = uv.os_unsetenv

os.all_handles        = uv.print_all_handles
os.active_handles     = uv.print_active_handles

if (not uv.os_setenv) then
    local env = require('env')
    os.setenv = env.set or noop
    os.unsetenv = env.unset or noop
end

-------------------------------------------------------------------------------

return exports
