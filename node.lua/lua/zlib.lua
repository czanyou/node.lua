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
meta.name        = "lnode/zlib"
meta.version     = "1.0.0"
meta.license     = "Apache 2"
meta.description = "zip lib"
meta.tags        = { "lnode", "zlib", "zip" }

local exports = { meta = meta }

local miniz = require('miniz')
local path  = require('path')
local fs    = require('fs')
local utils = require('utils')
local core  = require('core')

local Error  = core.Error
local Object = core.Object

-------------------------------------------------------------------------------
-- Gzip

local Gzip = Object:extend()

function exports.createGzip(options)
	return Gzip:new(options)
end


-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- Bundle 包生成器, 将零散的 lua 文件打包成统一的 bundle 包. 更方便文件的管理
--
-- @param basePath 要打包的目录
-- @param target 要生成的目标文件

local BundleBuilder = core.Emitter:extend()
exports.BundleBuilder = BundleBuilder

function BundleBuilder:initialize(basePath, target)
    self.basePath   = basePath
    self.target     = target
    self.files      = {}
end

function BundleBuilder:addFile(file)
    table.insert(self.files, file)
end

function BundleBuilder:build()
    if ((not self.basePath) or (not self.target)) then
        return 'bad path or target'
    end

    -- start
    print(" start...")

    local filename = self.target
    local dirname = path.dirname(filename)
    if (not fs.existsSync(dirname)) then
        fs.mkdirpSync(dirname)
    end

    local fd = fs.openSync(filename, "w", 511)
    if (not fd) then
        return filename .. ' open failed!'
    end

    local writer = miniz.new_writer()
    if (not writer) then
        return -1
    end

    self.writer = writer

    -- add bin files
    for _, file in ipairs(self.files) do
        self:copyStaticFile("", file)
    end

    -- finish
    local offset = nil
    fs.writeSync(fd, offset, writer:finalize())
    fs.closeSync(fd)

    print(" done.")
    return 0
end

function BundleBuilder:copyFile(srcfile, destfile)
    local fullPath = path.join(self.basePath, srcfile)
    local filedata = fs.readFileSync(fullPath)
    local filename = destfile:gsub('\\', '/')

    if (not filedata) then
        return
    end

    if os.platform() == "win32" then
        if (srcfile:endsWith(".lua")) then
            local script = load(filedata)
            if (script) then
                filedata = string.dump(script, true)
            end
        end
    end

    self.writer:add(filename, filedata, 9)
    print("  add file", console.colorize("highlight", filename))
end

function BundleBuilder:copyStaticFile(subPath, name)
    local childPath = path.join(subPath, name)
    local fullPath  = path.join(self.basePath, subPath, name)
    
    local stat = self:getFileInfo(fullPath)
    if stat.type == "directory" then
        local dirname = childPath:gsub('\\', '/') .. "/"
        if (dirname ~= './') then
            print("  add dir", console.colorize("success", dirname))
            self.writer:add(dirname, "")
        end

        self:copyStaticFolder(childPath)

    elseif stat.type == "file" then
        self:copyFile(childPath, childPath)
    end
end

function BundleBuilder:copyStaticFolder(subPath)
    local pathName = path.join(self.basePath, subPath)
    local files = fs.readdirSync(pathName)
    if (not files) then return end

    for i = 1, #files do
        local name = files[i]
        if (name:sub(1, 1) ~= ".") then
            self:copyStaticFile(subPath, name)
        end
    end
end

function BundleBuilder:getFileInfo(filename)
    local statInfo, err = fs.statSync(filename)
    if (not statInfo) then 
        return nil, err 
    end

    return {
        type    = string.lower(statInfo.type),
        size    = statInfo.size,
        mtime   = statInfo.mtime,
    }
end

exports.loadBundleFile = loadBundleFile

-------------------------------------------------------------------------------
-- ZipBuilder

local ZipBuilder = Object:extend()
exports.ZipBuilder = ZipBuilder

function ZipBuilder:build(pathname, skipList)
    local basename = path.basename(pathname)
    local dirname  = path.dirname(pathname)

    local fileList = {}
    if (skipList) then
        print('list:', #skipList)
        for _, item in ipairs(skipList) do
            fileList[item.name] = item
        end
    end

    local filename = path.join(dirname, basename .. ".zip")
    local fd = fs.openSync(filename, "w", 511)
    if (not fd) then
        return filename .. ' open failed!'
    end

    local writer = miniz.new_writer()
    if (not writer) then
        fs.closeSync(fd)
        return -1
    end

    local _copy_directory, _copy_file, _copy_file_data, _get_file_info

    -----------------------------------------------------------

    function _copy_directory(basePath, subPath)
        local fullName = path.join(basePath, subPath)
        local files = fs.readdirSync(fullName)
        if (not files) then 
            return 
        end

        for i = 1, #files do
            local name = files[i]
            if (name:sub(1, 1) ~= ".") then
                _copy_file(basePath, subPath, name)
            end
        end
    end

    function _copy_file(basePath, subPath, name)
        local childPath = path.join(subPath, name)
        local fullPath  = path.join(basePath, childPath)
        
        local stat = _get_file_info(fullPath)
        if stat.type == "directory" then
            local dirname = childPath .. "/"
            dirname = ""..dirname:gsub('\\', '/')
            print("  adding: " .. console.colorize("string", dirname))

            writer:add(dirname, "")
            _copy_directory(basePath, childPath)

        elseif stat.type == "file" then
            _copy_file_data(fullPath, childPath)
        end
    end

    function _copy_file_data(srcfile, destfile)
        local filedata = fs.readFileSync(srcfile)
        local filename = destfile:gsub('\\', '/')

        if (filedata) then
            local item = fileList[filename]
            if (item) then
                local md5sum = utils.bin2hex(utils.md5(filedata))
                if (item.md5sum == md5sum) then
                    --print(item.name)
                    return
                end
            end

            writer:add(filename, filedata, 9)
            print("  adding: " .. filename)
        end
    end

    function _get_file_info(filename)
        local statInfo, err = fs.statSync(filename)
        if (not statInfo) then 
            return nil, err 
        end

        return {
            type    = string.lower(statInfo.type),
            size    = statInfo.size,
            mtime   = statInfo.mtime,
        }
    end


    _copy_directory(pathname, "")

    -- finish
    local offset = nil
    fs.writeSync(fd, offset, writer:finalize())
    fs.closeSync(fd)

end

-------------------------------------------------------------------------------
-- ZipBuilder

local ZipReader = Object:extend()
exports.ZipReader = ZipReader



-------------------------------------------------------------------------------
-- exports

return exports
