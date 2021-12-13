--[[

Copyright 2014 The Luvit Authors. All Rights Reserved.
Copyright 2016-2020 The Node.lua Authors. All Rights Reserved.

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
local meta = {
    description = "Node-style process module for lnode"
}

local uv        = require('luv')
local lutils    = require('lutils')
local lnode     = require('lnode')
local version   = require('@version')

local process   = { meta = meta }
local exports   = process

-------------------------------------------------------------------------------
-- stream

if (not exports._stdin) then
    local _initStream = function(fd, mode)
        if uv.guess_handle(fd) == 'tty' then
            local stream = uv.new_tty(fd, mode)
            return stream, true

        else
            local stream = uv.new_pipe(false)
            uv.pipe_open(stream, fd)
            return stream, false
        end
    end

    exports._stdin, exports.isTTY = _initStream(0, true)
    exports._stderr = _initStream(2, false)
    exports._stdout = _initStream(1, false)
end

-------------------------------------------------------------------------------
-- env

local lenv = { }
function lenv.get(key)
    return lenv[key]
end

setmetatable(lenv, {
    __pairs = function(env)
        local environ = uv.os_environ()
        local keys = {}
        for key, value in pairs(environ) do
            table.insert(keys, key)
        end

        local index = 0
        return function(...)
            index = index + 1
            local name = keys[index]
            if name then
                return name, environ[name]
            end
        end
    end,

    __index = function(env, key)
        return uv.os_getenv(key)
    end,

    __newindex = function(env, key, value)
        if value then
            uv.os_setenv(key, value, 1)
        else
            uv.os_unsetenv(key)
        end
    end
})

-------------------------------------------------------------------------------
-- misc

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

function process.memoryUsage()
    return {
        rss = uv.resident_set_memory()
    }
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
        stdout:finish()

    else
        _onFinish()
    end

    local stderr = rawget(self, 'stderr')
    if (stderr) then
        stderr:once('finish', _onFinish)
        stderr:finish()

    else
        _onFinish()
    end
end

function process:on(event, listener)
    local Emitter   = require('core').Emitter
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
    local Emitter   = require('core').Emitter
    if (not self.emitter) then
        self.emitter = Emitter:new()
    end

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
-- stream

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
        local tty = require('tty')
        ret = tty.createReadStream(process._stdin)

    elseif (key == 'stdout') then
        local tty = require('tty')
        ret = tty.createWriteStream(process._stdout)

    elseif (key == 'stderr') then
        local tty = require('tty')
        ret = tty.createWriteStream(process._stderr)
    end

    if (ret) then
        rawset(self, key, ret)
    end

    return ret
end

setmetatable(process, metatable)

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
exports.nodePath    = lnode.NODE_LUA_PATH
exports.setgid      = uv.setgid         --
exports.setuid      = uv.setuid         --
exports.umask       = lutils.umask      --
exports.uptime      = uv.uptime         -- Number of seconds Node.lua has been running.
exports.version     = lnode.version     -- A compiled-in property that exposes NODE_VERSION.
exports.versions    = lnode.versions    -- A property exposing version strings of Node.lua and its dependencies.

--

exports.version = exports.version .. '.' .. version.build

return exports
