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
local meta = {
    description = "zip lib"
}

local exports = { meta = meta }

local miniz = require('miniz')
local path  = require('path')
local fs    = require('fs')
local util  = require('util')
local core  = require('core')

-------------------------------------------------------------------------------
-- ZipBuilder

---@class ZipBuilder
local ZipBuilder = core.Object:extend()
exports.ZipBuilder = ZipBuilder

function ZipBuilder:initialize()
    self.writer = nil
    self.pathname = nil
    self.fd = nil
    self.outname = nil
    self.fileList = {}
end

function ZipBuilder:build(pathname, skipList)
    self:close()

    local fileList = {}
    if (skipList) then
        for _, item in ipairs(skipList) do
            fileList[item.name] = item
        end
    end

    self.fileList = fileList

    local writer, err = miniz.createWriter()
    if (not writer) then
        return nil, err
    end

    -----------------------------------------------------------

    self.pathname = pathname
    self.writer = writer
    local hashdata = self:_addDirectory(pathname, "")
    console.log('hashdata', hashdata)

    table.insert(self.fileList, hashdata .. ':')

    local fileList = table.concat(self.fileList, '\r\n')
    console.log(fileList)

    self.writer:add('FILELIST.inf', fileList, 9)

    -- finish
    local filename = self.outname or (pathname .. '.zip')
    return fs.writeFileSync(filename, writer:finalize())
end

function ZipBuilder:close()
    local writer = self.writer
    self.writer = nil
    if (writer) then
        writer:close()
    end

    self.fileList = nil
end

function ZipBuilder:_addFileOrDirectory(basePath, subPath, name)
    local childPath = path.join(subPath, name)
    local fullPath  = path.join(basePath, childPath)

    -- console.log(basePath, childPath)

    local stat = fs.statSync(fullPath)
    local ret = nil
    if stat.type == "directory" then
        ret = self:_addDirectory(basePath, childPath)

    elseif stat.type == "file" then
        ret = self:_addFile(fullPath, childPath)
    end

    if (ret) then
        table.insert(self.fileList, ret .. ':' .. childPath)
    end

    return ret
end

function ZipBuilder:_addDirectory(basePath, subPath)
    local fullName = path.join(basePath, subPath)
    local files = fs.readdirSync(fullName)
    if (not files) then
        return
    end

    local fileList = {}
    for _, name in ipairs(files) do
        if (name:sub(1, 1) ~= ".") then
            local hashdata = self:_addFileOrDirectory(basePath, subPath, name)
            if (hashdata) then
                table.insert(fileList, hashdata .. '@' .. name)
            end
        end
    end

    if (#fileList <= 0) then
        return
    end

    fileList = table.concat(fileList, ';')
    return util.md5string(fileList)
end

function ZipBuilder:_addFile(srcfile, destfile)
    local filedata = fs.readFileSync(srcfile)
    if (not filedata) then
        return
    end

    local md5sum = util.md5string(filedata)
    local filename = destfile:gsub('\\', '/')
    local item = self.fileList[filename]
    if (item) then
        if (item.md5sum == md5sum) then
            --print(item.name)
            return
        end
    end

    self.writer:add(filename, filedata, 9)
    --print("  adding: " .. filename)
    return md5sum
end

-------------------------------------------------------------------------------
-- exports

exports.deflate = miniz.deflate
exports.inflate = miniz.inflate

exports.createReader = miniz.createReader
exports.createWriter = miniz.createWriter

return exports
