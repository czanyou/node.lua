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

local meta = { }
meta.name        = "lnode/child_process"
meta.version     = "1.1.0"
meta.license     = "Apache 2"
meta.description = "A port of node.js's child_process module for lnode."
meta.tags        = { "lnode", "spawn", "process" }

local exports = { meta = meta }

local core   = require('core')
local net    = require('net')
local uv     = require('uv')
local utils  = require('util')

local adapt  = utils.adapt

-------------------------------------------------------------------------------
-- Node.lua 通过 child_process 模块实现类似 popen(3) 的功能
-- @event error 
-- @event exit  
-- @event close 
--

local ChildProcess = core.Emitter:extend()

function ChildProcess:initialize(stdin, stdout, stderr, handle, pid)
    self.handle = handle
    self.pid    = pid
    self.stderr = stderr
    self.stdin  = stdin
    self.stdout = stdout
end

function ChildProcess:close(err)
    if self.handle and not uv.is_closing(self.handle) then
        uv.close(self.handle)
        self.handle = nil
    end
    
    self:_destroy(err)
end

function ChildProcess:isClosing()
    if self.handle and not uv.is_closing(self.handle) then
        return false
    end

    return true
end

function ChildProcess:disconnect()
    self:_cleanup()

    if (self.handle) then
        uv.unref(self.handle)

        self:emit('disconnect', self.pid)
    end
end

function ChildProcess:kill(signal)
    if self.handle and (not uv.is_closing(self.handle)) then 
        uv.process_kill(self.handle, signal or 'sigterm') 
    end
end

function ChildProcess:sendMessage(message, handle)
    if (self.stdin) then
        self.stdin:write(message)
    end
end

function ChildProcess:_cleanup(err)
    setImmediate( function()
        if self.stdout then
            self.stdout:_end(err) -- flush
            self.stdout:destroy(err) -- flush
        end

        if self.stderr then 
            self.stderr:destroy(err) 
        end

        if self.stdin  then 
            self.stdin:destroy(err)  
        end
    end )
end

function ChildProcess:_destroy(err)
    self:_cleanup(err)

    if err then
        setImmediate( function() 
            self:emit('error', err) 
        end)
    end
end

-------------------------------------------------------------------------------
-- Launches a new process with the given command, with command line arguments 
-- in args. If omitted, args defaults to an empty Array.
-- @param command String 要运行的命令
-- @param args Array 字符串参数列表
-- @param options Object 
-- - cwd 
-- - stdio 
-- - uid 
-- - gid 
-- @return ChildProcess object
-- 
function exports.spawn(command, args, options)
    local envPairs = { }
    local childProcess, _onExit, handle, pid
    local stdout, stdin, stderr, stdio, closesGot

    args = args or { }
    options = options or { }
    options.detached = options.detached or false

    if options.env then
        for k, v in pairs(options.env) do
            table.insert(envPairs, k .. '=' .. v)
        end
    end

    local _maybeClose = function ()
        closesGot = closesGot - 1
        if (closesGot == 0) then
            childProcess:emit('close', childProcess.exitCode, childProcess.signal)
        end
    end

    local _countStdio = function (stdio)
        local count = 0
        if stdio[1] then count = count + 1 end
        if stdio[2] then count = count + 1 end
        if stdio[3] then count = count + 1 end
        return count + 1
        -- for exit call
    end

    if options.stdio then
        stdio  = { }
        stdin  = options.stdio[1]
        stdout = options.stdio[2]
        stderr = options.stdio[3]

        stdio[1] = stdin  and stdin._handle
        stdio[2] = stdout and stdout._handle
        stdio[3] = stderr and stderr._handle

    else
        stdin  = net.Socket:new( { handle = uv.new_pipe(false) })
        stdout = net.Socket:new( { handle = uv.new_pipe(false) })
        stderr = net.Socket:new( { handle = uv.new_pipe(false) })
        stdio = { stdin._handle, stdout._handle, stderr._handle }
    end

    if stdio[1] then stdin :once('close', _maybeClose) end
    if stdio[2] then stdout:once('close', _maybeClose) end
    if stdio[3] then stderr:once('close', _maybeClose) end
    closesGot = _countStdio(stdio)

    _onExit = function (code, signal)
        childProcess.exitCode = code
        childProcess.signal   = signal
        childProcess:emit('exit', code, signal)

        _maybeClose()
        childProcess:close()
    end

    handle, pid = uv.spawn(command, {
        cwd         = options.cwd or nil,
        stdio       = stdio,
        args        = args,
        env         = envPairs,
        detached    = options.detached,
        uid         = options.uid,
        gid         = options.gid
    } , _onExit)

    --print('handle', command, handle, pid)

    local err = nil
    if (not handle) then
        err = core.Error:new(pid)
        pid = nil
    end

    childProcess = ChildProcess:new(stdin, stdout, stderr, handle, pid)

    if (not handle) then
        setImmediate( function()
            childProcess.exitCode = -127
            childProcess:emit('exit', childProcess.exitCode)
            childProcess:_destroy(err)
            _maybeClose()
        end)
    end

    return childProcess
end

---- Exec and execfile

local function _normalizeExecArgs(command, options, callback)
    -- function(command, callback)
    local argType = type(options)
    if (argType == 'function') or (argType == 'thread') then
        callback = options
        options = {}
    end

    local isWindows = (os.platform() == 'win32')

    local file, args
    if isWindows then
        file = 'cmd.exe'
        --args = { '/s', '/c', '"' .. command .. '"' }
        args = { '/s', '/c', command}
       
    else
        file = '/bin/sh'
        args = { '-c', command }
    end

    if (options and options.shell) then 
        file = options.shell 
    end

    --console.log(file, args, options, callback)
    return file, args, options, callback
end

local function _exec(file, args, options, callback)
    local defaultOptions = {
        timeout   = 0,
        maxBuffer = 4 * 1024,
        signal    = 'SIGTERM'
    }

    for k,v in pairs(defaultOptions) do
        if (not options[k]) then 
            options[k] = v 
        end
    end

    local child = exports.spawn(file, args, options)

    local stdout, stderr = {}, {}
    local exited, killed = false, false
    local stdoutLen, stderrLen = 0, 0
    local timeoutId
    local err = {}
    local called = 2

    local _exitHandler = function (code, signal)
        if timeoutId then
            clearTimeout(timeoutId)
            timeoutId = nil
        end

        if exited then return end

        called = called - 1
        if called == 0 then
            if signal then err.signal = signal end
            if not code then
                err.message = 'Command failed: ' .. file

            elseif code == 0 then
                err = nil

            else
                err.code = code
                err.message = 'Command return with (' .. tostring(code) .. ')'
            end

            exited = true
            if not callback then return end
            callback(err, table.concat(stdout, ""), table.concat(stderr, ""))
        end
    end

    local _onClose = function (_exitCode)
        _exitHandler(_exitCode, nil)
    end

    local _kill = function ()
        child.stdout:emit('close', 1, options.signal)
        child.stderr:emit('close', 1, options.signal)
        child:emit('close', 1, options.signal)
        killed = true
        _exitHandler(1, options.signal)
    end

    if (options.timeout > 0) then
        timeoutId = setTimeout(options.timeout, function()
            _kill()
            timeoutId = nil
        end)
    end

    child.stdout:on('data', function(chunk)
        stdoutLen = stdoutLen + #chunk
        if (stdoutLen > options.maxBuffer) then
            _kill()
        else
            table.insert(stdout, chunk)
        end
    end ):once('end', _exitHandler)

    child.stderr:on('data', function(chunk)
        stderrLen = stderrLen + #chunk
        if (stderrLen > options.maxBuffer) then
            _kill()
        else
            table.insert(stderr, chunk)
        end
    end )

    child:once('close', _onClose)
end

function exports.exec(command, options, callback)
    -- options is optional
    return exports.execFile(_normalizeExecArgs(command, options, callback))
end

function exports.execFile(file, args, options, callback)
    -- Make callback, args and options optional
    -- no option or args
    if (type(args) == 'function') or (type(args) == 'thread') then
        -- function(file, callback)
        callback = args
        args, options = {}, {}

    elseif (type(options) == 'function') or (type(options) == 'thread') then
        -- function(file, args, callback)
        callback = options
        options  = {}

    elseif (not args) and (not options) and (not callback) then
        -- function(file)
        callback = function() end -- noop
        options  = {}
        args     = {}

    elseif (not options) then
        -- function(file, args, nil, callback)
        options = {}

    elseif (not args) then
        -- function(file, nil, nil, callback)
        args    = {}
    end

    return adapt(callback, _exec, file, args, options)
end

function exports.fork(command, options, callback)
    -- TODO: 
end

return exports;