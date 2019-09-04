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
The process object is a global object and can be accessed from anywhere. It is
an instance of EventEmitter.
--]]

local meta = { }
meta.description = "Node-style process module for lnode"
meta.license     = "Apache 2"
meta.name        = "lnode/process"
meta.tags        = { "lnode", "process" }
meta.version     = "1.0.1"

local patch     = 227

local env       = require('env')
local uv        = require('luv')
local Emitter   = require('core').Emitter
local lutils    = require('lutils')
local lnode     = require('lnode')

local process   = { meta = meta }
local exports   = process

-------------------------------------------------------------------------------
-- env

local lenv = { }
function lenv.get(key)
    return lenv[key]
end

setmetatable(lenv, {
    __pairs = function(table)
        local keys = env.keys() or {}
        local index = 0
        return function(...)
            index = index + 1
            local name = keys[index]
            if name then
                return name, table[name]
            end
        end
    end,

    __index = function(table, key)
        return env.get(key)
    end,

    __newindex = function(table, key, value)
        if value then
            env.set(key, value, 1)
        else
            env.unset(key)
        end
    end
} )

-------------------------------------------------------------------------------

local timer = nil

function process.nextTick(...)
    if (not timer) then
        timer = require('timer')
    end

    timer.setImmediate(...)
end

function process.kill(pid, signal)
    uv.kill(pid, signal or 'sigterm')
end

-------------------------------------------------------------------------------
-- emitter

local signalWraps = { }

process.emitter = nil

function process:emit(event, ...)
    if (self.emitter) then
        self.emitter:emit(event, ...)
    end
end

function process:exit(code)
    local left = 2
    code = code or 0

    local _onFinish = function()
        left = left - 1
        if (left > 0) then
            return
        end

        if (self.emitter) then
            self.emitter:emit('exit', code)
        end

        os.exit(code)
    end

    self.isExit = true

    local stdout = rawget(self, 'stdout')
    if (stdout) then
        stdout:once('finish', _onFinish)
        stdout:_end()

    else
        _onFinish()
    end

    local stderr = rawget(self, 'stderr')
    if (stderr) then
        stderr:once('finish', _onFinish)
        stderr:_end()

    else
        _onFinish()
    end
end

function process:on(event, listener)
    if (not self.emitter) then
        self.emitter = Emitter:new()
    end

    local emitter = self.emitter
    if (event == "error") or (event == "exit") then
        emitter:on(event, listener)
        return
    end

    if not signalWraps[event] then
        local signal = uv.new_signal()
        signalWraps[event] = signal
        uv.unref(signal)
        uv.signal_start(signal, event, function()
            emitter:emit(event)
        end)
    end

    emitter:on(event, listener)
end

function process:once(event, listener)
    local emitter = self.emitter
    if (emitter) then
        emitter:once(event, listener)
    end
end

function process:removeListener(event, listener)
    local signal = signalWraps[event]
    if not signal then
        return
    end

    signal:stop()
    uv.close(signal)
    signalWraps[event] = nil

    if (self.emitter) then
        self.emitter:removeListener(event, listener)
    end
end

-------------------------------------------------------------------------------
--

exports.arch        = lutils.os_arch    --
exports.argv        = arg               --
exports.chdir       = uv.chdir          -- Changes the current working directory of the process or throws an exception if that fails
exports.cwd         = uv.cwd            -- Returns the current working directory of the process.
exports.env         = lenv              -- An object containing the user environment. See environ(7).
exports.execPath    = uv.exepath()      --
exports.exitCode    = 0                 --
exports.getgid      = uv.getgid         --
exports.getuid      = uv.getuid         --
exports.hrtime      = uv.hrtime         -- Returns the current high-resolution real time
exports.now         = uv.now            --
exports.pid         = uv.getpid()       -- The PID of the process.
exports.platform    = lutils.os_platform
exports.rootPath    = lnode.NODE_LUA_ROOT
exports.setgid      = uv.setgid         --
exports.setuid      = uv.setuid         --
exports.umask       = lutils.umask      --
exports.uptime      = uv.uptime         -- Number of seconds Node.lua has been running.
exports.version     = lnode.version     -- A compiled-in property that exposes NODE_VERSION.
exports.versions    = lnode.versions    -- A property exposing version strings of Node.lua and its dependencies.

--

exports.version = exports.version .. '.' .. patch

-------------------------------------------------------------------------------
-- stream

local console = require('console')

local UvStreamWritable = nil

local function _newWritable(pipe)
    if (UvStreamWritable) then
        return UvStreamWritable:new(pipe)
    end

    local Writable  = require('stream').Writable

    UvStreamWritable = Writable:extend()

    function UvStreamWritable:initialize(handle)
        Writable.initialize(self)
        self.handle = handle
    end

    function UvStreamWritable:_write(data, callback)
        uv.write(self.handle, data, callback)
    end

    return UvStreamWritable:new(pipe)
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

local UvStreamReadable = nil

local function _newReadable(pipe)
    if (UvStreamReadable) then
        return UvStreamReadable:new(pipe)
    end

    local Readable  = require('stream').Readable
    local utils     = require('util')

    UvStreamReadable = Readable:extend()
    function UvStreamReadable:initialize(handle)
        Readable.initialize(self, { highWaterMark = 0 })
        self._readableState.reading = false
        self.reading = false
        self.handle  = handle
        self:on('pause', utils.bind(self._onPause, self))
    end

    function UvStreamReadable:_onPause()
        self._readableState.reading = false
        self.reading = false
        uv.read_stop(self.handle)
    end

    function UvStreamReadable:_read(n)
        local _onRead = function (err, data)
            if err then
                return self:emit('error', err)
            end
            self:push(data)
        end

        if not uv.is_active(self.handle) then
            self.reading = true
            uv.read_start(self.handle, _onRead)
        end
    end

    return UvStreamReadable:new(pipe)
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

local metatable = {}

metatable.__index = function(self, key)
    if (key == 'title') then
        return uv.get_process_title()
    end

    local ret = rawget(self, key)
    if (ret ~= nil) then
        return ret
    end

    if rawget(self, 'isExit') then
        return ret
    end

    if (key == 'stdin') then
        ret = _newReadable(console.stdin)

    elseif (key == 'stdout') then
        ret = _newWritable(console.stdout)

    elseif (key == 'stderr') then
        ret = _newWritable(console.stderr)
    end

    if (ret) then
        rawset(self, key, ret)
    end

    return ret
end

setmetatable(process, metatable)

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

return exports
