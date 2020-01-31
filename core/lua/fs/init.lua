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
local util      = require('util')
local uv        = require('luv')
local fs        = require('./file')
local Error     = require('core').Error

local noop = function() end

fs.meta         = meta
fs.statfs       = lutils.os_statfs
fs.fileLock     = lutils.os_file_lock

-- ----------------------------------------------------------------------------
--

function fs.access(path, flags, callback)
    local ft = type(flags)
    if (ft == 'function' or ft == 'thread') and
        (callback == nil) then
        callback, flags = flags, nil
    end

    if flags == nil then
        flags = 0
    end

    return uv.fs_access(path, flags, callback or noop)
end

function fs.accessSync(path, flags)
    if flags == nil then
        flags = 0
    end

    return uv.fs_access(path, flags)
end

function fs.exists(path, callback)
    local stat, err = uv.fs_stat(path)
    callback(err, stat ~= nil)
end

function fs.existsSync(path)
    local stat, err = uv.fs_stat(path)
    return stat ~= nil, err
end

function fs.rename(path, newPath, callback)
    return uv.fs_rename(path, newPath, callback or noop)
end

function fs.renameSync(path, newPath)
    return uv.fs_rename(path, newPath)
end

function fs.copyfile(src, dest, flags, callback)
    if (type(flags) == 'function') then
        callback = flags
        flags = 0
    end

    return uv.fs_copyfile(src, dest, (flags or 0), callback or noop)
end

function fs.copyfileSync(src, dest, flags)
    return uv.fs_copyfile(src, dest, (flags or 0))
end

-- ----------------------------------------------------------------------------
--

function fs.chmod(path, mode, callback)
    return uv.fs_chmod(path, mode, callback or noop)
end

function fs.chmodSync(path, mode)
    return uv.fs_chmod(path, mode)
end

function fs.fchmod(fd, mode, callback)
    return uv.fs_fchmod(fd, mode, callback or noop)
end

function fs.fchmodSync(fd, mode)
    return uv.fs_fchmod(fd, mode)
end

-- ----------------------------------------------------------------------------
--

function fs.chown(path, uid, gid, callback)
    return uv.fs_chown(path, uid, gid, callback or noop)
end

function fs.chownSync(path, uid, gid)
    return uv.fs_chown(path, uid, gid)
end

function fs.fchown(fd, uid, gid, callback)
    return uv.fs_fchown(fd, uid, gid, callback or noop)
end

function fs.fchownSync(fd, uid, gid)
    return uv.fs_fchown(fd, uid, gid)
end

-- ----------------------------------------------------------------------------
--

function fs.ftruncate(fd, offset, callback)
    local ot = type(offset)

    -- (fd, callback)
    if (ot == 'function' or ot == 'thread') and (callback == nil) then
        callback, offset = offset, nil
    end

    if offset == nil then
        offset = 0
    end

    return uv.fs_ftruncate(fd, offset, callback or noop)
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

            return uv.fs_ftruncate(fd, offset, cb)
        end
    end)
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

-- ----------------------------------------------------------------------------
--

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

    return uv.fs_mkdir(pathname, mode, callback or noop)
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
    return  uv.fs_mkdtemp(template, callback or noop)
end

function fs.mkdtempSync(template)
    return uv.fs_mkdtemp(template)
end

function fs.readdir(path, callback)
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
    
    return _readdir(path, callback or noop)
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

function fs.rmdir(path, callback)
    return uv.fs_rmdir(path, callback or noop)
end

function fs.rmdirSync(path)
    return uv.fs_rmdir(path)
end

function fs.scandir(path, callback)
    local function _scandir(path, callback)
        uv.fs_scandir(path, function(err, req)
            if err then
                return callback(err)
            end
    
            callback(nil, function()
                return uv.fs_scandir_next(req)
            end)
        end)
    end
    
    return _scandir(path, callback or noop)
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

-- ----------------------------------------------------------------------------
--

function fs.fstat(fd, callback)
    return uv.fs_fstat(fd, callback or noop)
end

function fs.fstatSync(fd)
    return uv.fs_fstat(fd)
end

function fs.lstat(pathname, callback)
    return uv.fs_lstat(pathname, callback or noop)
end

function fs.lstatSync(pathname)
    return uv.fs_lstat(pathname)
end

function fs.stat(path, callback)
    return uv.fs_stat(path, callback or noop)
end

function fs.statSync(path)
    return uv.fs_stat(path)
end

-- ----------------------------------------------------------------------------
--

function fs.link(pathname, newPath, callback)
    return uv.fs_link(pathname, newPath, callback or noop)
end

function fs.linkSync(pathname, newPath)
    return uv.fs_link(pathname, newPath)
end

function fs.readlink(path, callback)
    return uv.fs_readlink(path, callback or noop)
end

function fs.readlinkSync(path)
    return uv.fs_readlink(path)
end

function fs.symlink(path, newPath, options, callback)
    local ot = type(options)

    -- (path, newPath, callback)
    if (ot == 'function' or ot == 'thread') and (callback == nil) then
        callback, options = options, nil
    end

    return uv.fs_symlink(path, newPath, options, callback or noop)
end

function fs.symlinkSync(path, newPath, options)
    return uv.fs_symlink(path, newPath, options)
end

function fs.unlink(path, callback)
    return uv.fs_unlink(path, callback or noop)
end

function fs.unlinkSync(path)
    return uv.fs_unlink(path)
end

-- ----------------------------------------------------------------------------
--

function fs.futime(fd, atime, mtime, callback)
    return uv.fs_futime(fd, atime, mtime, callback or noop)
end

function fs.futimeSync(fd, atime, mtime)
    return uv.fs_futime(fd, atime, mtime)
end

function fs.utime(path, atime, mtime, callback)
    return uv.fs_utime(path, atime, mtime, callback or noop)
end

function fs.utimeSync(path, atime, mtime)
    return uv.fs_utime(path, atime, mtime)
end

-- ----------------------------------------------------------------------------
--

local _wrap = nil

function fs.wrap(module)
    local function wrapFunction(func)
        return function(...)
            local args = { ... }
            local callback = args[#args]

            if (type(callback) ~= 'thread') then
                return func(...)
            end

            args[#args] = nil
            local results = table.pack(util.await(func, table.unpack(args)))
            return results[2], results[1]
        end
    end

    if _wrap then
        return _wrap
    end

    local result = {}
    for name, func in pairs(fs) do
        if (name:endsWith('Sync')) then
            result[name] = func
            goto continue

        elseif (type(func) ~= 'function') then
            result[name] = func
            goto continue
        end

        result[name] = wrapFunction(func)

        ::continue::
    end

    _wrap = result
    return result
end

-- ----------------------------------------------------------------------------
--

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

return fs
