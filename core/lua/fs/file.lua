--[[

Copyright 2014-2015 The Luvit Authors. All Rights Reserved.
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

local uv        = require('luv')
local core      = require('core')

local fs = {}

local noop = function() end

function fs.close(fd, callback)
    return uv.fs_close(fd, callback or noop)
end

function fs.closeSync(fd)
    return uv.fs_close(fd)
end

function fs.open(path, flags, mode, callback)
    local ft = type(flags)
    local mt = type(mode)

    -- (path, callback)
    if (ft == 'function' or ft == 'thread') and (mode == nil and callback == nil) then
        callback, flags = flags, nil

    -- (path, flags, callback)
    elseif (mt == 'function' or mt == 'thread') and (callback == nil) then
        callback, mode = mode, nil
    end

    -- Default flags to 'r'
    if flags == nil then
        flags = 'r'
    end

    -- Default mode to 0666
    if mode == nil then
        mode = 438        -- 0666
        -- Assume strings are octal numbers

    elseif mt == 'string' then
        mode = tonumber(mode, 8)
    end

    return uv.fs_open(path, flags, mode, callback or noop)
end

function fs.openSync(path, flags, mode)
    if flags == nil then
        flags = "r"
    end

    if mode == nil then
        mode = 438 --  0666

    elseif type(mode) == "string" then
        mode = tonumber(mode, 8)
    end

    return uv.fs_open(path, flags, mode)
end

function fs.read(fd, size, offset, callback)
    local st = type(size)
    local ot = type(offset)

    if (st == 'function' or st == 'thread') and (offset == nil and callback == nil) then
        callback, size = size, nil

    elseif (ot == 'function' or ot == 'thread') and (callback == nil) then
        callback, offset = offset, nil
    end

    if size == nil then
        size = 4096
    end

    if offset == nil then
        offset = -1
    end

    return uv.fs_read(fd, size, offset, callback or noop)
end

function fs.readSync(fd, size, offset)
    if size == nil then
        size = 4096
    end

    if offset == nil then
        offset = -1
    end

    return uv.fs_read(fd, size, offset)
end

function fs.fdatasync(fd, callback)
    return uv.fs_fdatasync(fd, callback or noop)
end

function fs.fdatasyncSync(fd)
    return uv.fs_fdatasync(fd)
end

function fs.fsync(fd, callback)
    return uv.fs_fsync(fd, callback or noop)
end

function fs.fsyncSync(fd)
    return uv.fs_fsync(fd)
end

function fs.write(fd, offset, data, callback)
    local ot = type(offset)

    -- (fd, callback, data)
    if (ot == 'function' or ot == 'thread') and (callback == nil) then
        callback, offset = offset, nil
    end

    if (offset == nil) then
        offset = -1 -- -1 means append
    end

    return uv.fs_write(fd, data, offset, callback or noop)
end

function fs.writeSync(fd, offset, data)
    if (offset == nil) then
        offset = -1 -- -1 means append
    end

    return uv.fs_write(fd, data, offset)
end


-- ----------------------------------------------------------------------------

---@class FileHandle
local FileHandle = core.Object:extend()

function FileHandle:initialize(fd)
    self.fd = fd
end

function FileHandle:close(callback)
    return fs.close(self.fd, callback)
end

---@param size number
---@param offset number
function FileHandle:read(size, offset, callback)
    return fs.read(self.fd, size, offset, callback)
end

function FileHandle:fdatasync(callback)
    return fs.fdatasync(self.fd, callback)
end

function FileHandle:fsync(callback)
    return fs.fsync(self.fd, callback)
end

---@param offset number
---@param data string
function FileHandle:write(offset, data, callback)
    return fs.write(self.fd, offset, data, callback)
end

function FileHandle:fchown(uid, gid, callback)
    return fs.fchown(self.fd, uid, gid, callback)
end

---@param offset number
function FileHandle:ftruncate(offset, callback)
    return fs.ftruncate(self.fd, offset, callback)
end

function FileHandle:fstat(callback)
    return fs.fstat(self.fd, callback)
end

function FileHandle:futime(atime, mtime, callback)
    return fs.futime(self.fd, atime, mtime, callback)
end

---@param path string
---@param flags number
---@param mode number
---@return Promise
function fs.openFile(path, flags, mode)
    local Promise = require('promise')

    ---@type Promise
    local promise = Promise.new()

    fs.open(path, flags, mode, function(err, fd)
        if (err ~= nil) then
            promise:reject(err)
        else
            local file = FileHandle:new(fd)
            promise:resolve(file)
        end
    end)

    return promise
end

fs.FileHandle = FileHandle

-- ----------------------------------------------------------------------------
--

function fs.appendFile(filename, data, callback)
    callback = callback or function() end
    local function _write(fd, offset, buffer, callback)
        local function _onWrite(err, written)
            if err then return fs.close(fd, function() callback(err) end) end
            if written == #buffer then
                fs.close(fd, callback)
            else
                offset = offset + written
                buffer = buffer:sub(offset)
                _write(fd, offset, buffer, callback)
            end
        end
        fs.write(fd, -1, data, _onWrite)
    end

    --[[ 0666 ]]
    fs.open(filename, "a", 438, function(err, fd)
        if err then return callback(err) end
        _write(fd, -1, data, callback)
    end)
end

function fs.appendFileSync(path, data)
    local written
    local fd, err = fs.openSync(path, 'a')
    if not fd then return err end

    written, err = fs.writeSync(fd, -1, data)
    if not written then fs.close(fd); return err end
    fs.close(fd)
end

local function _readFile(path, callback)
    local fd, _onStat, _onRead, _onChunk, pos, chunks

    --[[ 0666 ]]
    uv.fs_open(path, "r", 438, function(err, result)
        if err then return
            callback(err)
        end

        fd = result
        uv.fs_fstat(fd, _onStat)
    end )

    _onStat = function(err, stat)
        if err then return _onRead(err) end
        if stat.size > 0 then
            uv.fs_read(fd, stat.size, 0, _onRead)

        else
            -- the kernel lies about many files.
            -- Go ahead and try to read some bytes.
            pos = 0
            chunks = { }
            uv.fs_read(fd, 8192, 0, _onChunk)
        end
    end

    _onRead = function(err, chunk)
        uv.fs_close(fd, noop)
        return callback(err, chunk)
    end

    _onChunk = function(err, chunk)
        if err then
            uv.fs_close(fd, noop)
            return callback(err)
        end

        if chunk and #chunk > 0 then
            chunks[#chunks + 1] = chunk
            pos = pos + #chunk
            return uv.fs_read(fd, 8192, pos, _onChunk)
        end

        uv.fs_close(fd, noop)
        return callback(nil, table.concat(chunks))
    end
end

function fs.readFile(path, callback)
    return _readFile(path, callback or noop)
end

function fs.readFileSync(path, options)
    local fd, stat, chunk, err
    fd, err = uv.fs_open(path, "r", 438) --[[ 0666 ]]
    if err then
        return false, err
    end

    stat, err = uv.fs_fstat(fd)
    if stat then
        if stat.size > 0 then
            chunk, err = uv.fs_read(fd, stat.size, 0)

        else
            local chunks = { }
            local pos = 0
            while true do
                chunk, err = uv.fs_read(fd, 8192, pos)
                if not chunk or #chunk == 0 then
                    break
                end

                pos = pos + #chunk
                chunks[#chunks + 1] = chunk

            end
            if not err then
                chunk = table.concat(chunks)
            end
        end
    end

    uv.fs_close(fd, noop)
    return chunk, err
end

local function _writeFile(path, data, callback)
    local fd, _onWrite

    --[[ 0666 ]]
    uv.fs_open(path, "w", 438, function(err, result)
        if err then
            return callback(err)
        end

        fd = result
        uv.fs_write(fd, data, 0, _onWrite)
    end)

    _onWrite = function(err)
        uv.fs_close(fd, noop)
        return callback(err)
    end
end

function fs.writeFile(path, data, callback)
    _writeFile(path, data, callback or noop)
end

function fs.writeFileSync(path, data)
    local _, fd, err

    fd, err = uv.fs_open(path, "w", 438) --[[ 0666 ]]
    if err then
        return false, err
    end

    --console.trace()

    _, err = uv.fs_write(fd, data, 0)
    uv.fs_close(fd, noop)
    return not err, err
end

-- ----------------------------------------------------------------------------
--

function fs.sendfile(outFd, inFd, offset, length, callback)
    return uv.fs_sendfile(outFd, inFd, offset, length, callback or noop)
end

function fs.sendfileSync(outFd, inFd, offset, length)
    return uv.fs_sendfile(outFd, inFd, offset, length)
end

return fs
