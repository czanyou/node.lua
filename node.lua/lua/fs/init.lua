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
meta.name        = "lnode/fs"
meta.version     = "1.2.2"
meta.license     = "Apache 2"
meta.description = "Node-style filesystem module for lnode"
meta.tags        = { "lnode", "fs", "stream" }

local lutils    = require('lutils')
local uv        = require('uv')
local adapt     = require('utils').adapt
local Error     = require('core').Error

local exports = { meta = meta }

local fs        = exports

fs.statfs       = lutils.os_statfs
fs.fileLock     = lutils.os_file_lock

function fs.access(path, flags, callback)
    local ft = type(flags)
    if (ft == 'function' or ft == 'thread') and
        (callback == nil) then
        callback, flags = flags, nil
    end

    if flags == nil then
        flags = 0
    end

    return adapt(callback, uv.fs_access, path, flags)
end

function fs.accessSync(path, flags)
    if flags == nil then
        flags = 0
    end

    return uv.fs_access(path, flags)
end

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

function fs.chmod(path, mode, callback)
    return adapt(callback, uv.fs_chmod, path, mode)
end

function fs.chmodSync(path, mode)
    return uv.fs_chmod(path, mode)
end

function fs.chown(path, uid, gid, callback)
    return adapt(callback, uv.fs_chown, path, uid, gid)
end

function fs.chownSync(path, uid, gid)
    return uv.fs_chown(path, uid, gid)
end

function fs.close(fd, callback)
    return adapt(callback, uv.fs_close, fd)
end

function fs.closeSync(fd)
    return uv.fs_close(fd)
end

function fs.copy(sourceFile, destFile, callback)
    local fileInfo = fs.stat(sourceFile, function(err, fileInfo)
        if (not fileInfo) or (err) then
            if (callback) then
                callback(err or 'Bad source file')
            end       
            return
        end

        fs.readFile(sourceFile, function(err, fileData)
            if (not fileData) or (err) then
                if (callback) then
                    callback(err or 'Bad source file')
                end 
                return
            end

            fs.writeFile(destFile, fileData, function(err)
                if (callback) then
                    callback(err)
                end
            end)
        end)
    end)
end

function fs.copySync(sourceFile, destFile)
    local fileInfo = fs.statSync(sourceFile)
    if (not fileInfo) then
        return
    end

    local fileData = fs.readFileSync(sourceFile)
    if (fileData) then
        fs.writeFileSync(destFile, fileData)
    end

    return true
end

function fs.exists(path, callback)
    local stat, err = uv.fs_stat(path)
    callback(err, stat ~= nil)
end

function fs.existsSync(path)
    local stat, err = uv.fs_stat(path)
    return stat ~= nil, err
end

function fs.fchmod(fd, mode, callback)
    return adapt(callback, uv.fs_fchmod, fd, mode)
end

function fs.fchmodSync(fd, mode)
    return uv.fs_fchmod(fd, mode)
end

function fs.fchown(fd, uid, gid, callback)
    return adapt(callback, uv.fs_fchown, fd, uid, gid)
end

function fs.fchownSync(fd, uid, gid)
    return uv.fs_fchown(fd, uid, gid)
end

function fs.fdatasync(fd, callback)
    return adapt(callback, uv.fs_fdatasync, fd)
end

function fs.fdatasyncSync(fd)
    return uv.fs_fdatasync(fd)
end

function fs.fstat(fd, callback)
    return adapt(callback, uv.fs_fstat, fd)
end

function fs.fstatSync(fd)
    return uv.fs_fstat(fd)
end

function fs.fsync(fd, callback)
    return adapt(callback, uv.fs_fsync, fd)
end

function fs.fsyncSync(fd)
    return uv.fs_fsync(fd)
end

function fs.ftruncate(fd, offset, callback)
    local ot = type(offset)

    -- (fd, callback)
    if (ot == 'function' or ot == 'thread') and (callback == nil) then
        callback, offset = offset, nil
    end

    if offset == nil then
        offset = 0
    end

    return adapt(callback, uv.fs_ftruncate, fd, offset)
end

function fs.truncate(fname, offset, callback)
    local ot = type(offset)

    if (ot == 'function' or ot == 'thread') and
        (callback == nil) then
        callback, offset = offset, nil
    end

    if offset == nil then
        offset = 0
    end

    fs.open(fname, 'w', function(err, fd)
        if (err) then
            callback(err)
        else
            local cb = function(error)
                uv.fs_close(fd)
                callback(error)
            end
            return adapt(cb, uv.fs_ftruncate, fd, offset)
        end
    end )
end

function fs.ftruncateSync(fd, offset)
    if offset == nil then
        offset = 0
    end

    return uv.fs_ftruncate(fd, offset)
end

function fs.truncateSync(fname, offset)
    if offset == nil then
        offset = 0
    end

    local fd, err = fs.openSync(fname, "w")
    local ret
    if fd then
        ret, err = uv.fs_ftruncate(fd, offset)
        fs.closeSync(fd)
    end

    return ret, err
end

function fs.futime(fd, atime, mtime, callback)
    return adapt(callback, uv.fs_futime, fd, atime, mtime)
end

function fs.futimeSync(fd, atime, mtime)
    return uv.fs_futime(fd, atime, mtime)
end

function fs.link(pathname, newPath, callback)
    return adapt(callback, uv.fs_link, pathname, newPath)
end

function fs.linkSync(pathname, newPath)
    return uv.fs_link(pathname, newPath)
end

function fs.lstat(pathname, callback)
    return adapt(callback, uv.fs_lstat, pathname)
end

function fs.lstatSync(pathname)
    return uv.fs_lstat(pathname)
end

function fs.mkdir(pathname, mode, callback)
    local mt = type(mode)

    -- (pathname, callback)
    if (mt == 'function' or mt == 'thread') and
        (callback == nil) then
        callback, mode = mode, nil
    end

    if mode == nil then
        mode = 511        -- 0777

    elseif type(mode) == 'string' then
        mode = tonumber(mode, 8)
    end

    return adapt(callback, uv.fs_mkdir, pathname, mode)
end

function fs.mkdirSync(pathname, mode)
    if mode == nil then
        mode = 511

    elseif type(mode) == 'string' then
        mode = tonumber(mode, 8)
    end

    return uv.fs_mkdir(pathname, mode)
end

function fs.mkdirpSync(pathname, mode)
    local path = require("path")
    
    local success, err = fs.mkdirSync(pathname, mode)
    if success or string.match(err, "^EEXIST") then
        return true
    end

    if string.match(err, "^ENOENT:") then
        success, err = fs.mkdirpSync(path.join(pathname, ".."), mode)
        if not success then return nil, err end
        return fs.mkdirSync(pathname, mode)
    end

    return nil, err
end

function fs.mkdtemp(template, callback)
    return adapt(callback, uv.fs_mkdtemp, template)
end

function fs.mkdtempSync(template)
    return uv.fs_mkdtemp(template)
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

    return adapt(callback, uv.fs_open, path, flags, mode)
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

    return adapt(callback, uv.fs_read, fd, size, offset)
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

local function _readdir(path, callback)
    uv.fs_scandir(path, function(err, req)
        if err then return callback(Error:new(err)) end
        local files = { }
        local i = 1
        while true do
            local name = uv.fs_scandir_next(req)
            if not name then break end
            files[i] = name
            i = i + 1
        end

        callback(nil, files)
    end )
end

function fs.readdir(path, callback)
    return adapt(callback, _readdir, path)
end

function fs.readdirSync(path)
    local req = uv.fs_scandir(path)

    local files = { }
    local i = 1

    if (not req) then
        --console.trace(path)
        return nil
    end
  
    while true do
        local name = uv.fs_scandir_next(req)
        if not name then 
            break 
        end
        
        files[i] = name
        i = i + 1
    end

    return files
end

local function noop() end

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
    return adapt(callback, _readFile, path)
end

function fs.readFileSync(path)
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

function fs.readlink(path, callback)
    return adapt(callback, uv.fs_readlink, path)
end

function fs.readlinkSync(path)
    return uv.fs_readlink(path)
end

function fs.rename(path, newPath, callback)
    return adapt(callback, uv.fs_rename, path, newPath)
end

function fs.renameSync(path, newPath)
    return uv.fs_rename(path, newPath)
end

function fs.rmdir(path, callback)
    return adapt(callback, uv.fs_rmdir, path)
end

function fs.rmdirSync(path)
    return uv.fs_rmdir(path)
end

local function _scandir(path, callback)
    uv.fs_scandir(path, function(err, req)
        if err then 
            return callback(err) 
        end

        callback(nil, function()
            return uv.fs_scandir_next(req)
        end )
    end )
end

function fs.scandir(path, callback)
    return adapt(callback, _scandir, path)
end

function fs.scandirSync(path)
    local req = uv.fs_scandir(path)
    return function()
        if (req == nil) then
            return nil
        end

        return uv.fs_scandir_next(req)
    end
end

function fs.sendfile(outFd, inFd, offset, length, callback)
    return adapt(callback, uv.fs_sendfile, outFd, inFd, offset, length)
end

function fs.sendfileSync(outFd, inFd, offset, length)
    return uv.fs_sendfile(outFd, inFd, offset, length)
end

function fs.stat(path, callback)
    return adapt(callback, uv.fs_stat, path)
end

function fs.statSync(path)
    return uv.fs_stat(path)
end

function fs.symlink(path, newPath, options, callback)
    local ot = type(options)

    -- (path, newPath, callback)
    if (ot == 'function' or ot == 'thread') and (callback == nil) then
        callback, options = options, nil
    end

    return adapt(callback, uv.fs_symlink, path, newPath, options)
end

function fs.symlinkSync(path, newPath, options)
    return uv.fs_symlink(path, newPath, options)
end

function fs.unlink(path, callback)
    return adapt(callback, uv.fs_unlink, path)
end

function fs.unlinkSync(path)
    return uv.fs_unlink(path)
end

function fs.utime(path, atime, mtime, callback)
    return adapt(callback, uv.fs_utime, path, atime, mtime)
end

function fs.utimeSync(path, atime, mtime)
    return uv.fs_utime(path, atime, mtime)
end

function fs.write(fd, offset, data, callback)
    local ot = type(offset)

    -- (fd, callback, data)
    if (ot == 'function' or ot == 'thread') and
        (callback == nil) then
        callback, offset = offset, nil
    end

    if (offset == nil) then
        offset = -1 -- -1 means append
    end

    return adapt(callback, uv.fs_write, fd, data, offset)
end

function fs.writeSync(fd, offset, data)
    if (offset == nil) then
        offset = -1 -- -1 means append
    end

    return uv.fs_write(fd, data, offset)
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
    adapt(callback, _writeFile, path, data)
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

local WriteStream = nil
local ReadStream  = nil

function fs.createWriteStream(path, options)
    if (not WriteStream) then
        WriteStream = require('fs/stream').WriteStream
    end
    return WriteStream:new(path, options)
end

function fs.createReadStream(path, options)
    if (not ReadStream) then
        ReadStream = require('fs/stream').ReadStream
    end   
    return ReadStream:new(path, options)
end

return exports
