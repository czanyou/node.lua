--[[

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

local core      = require('core')
local fs        = require('fs')
local json      = require('json')
local miniz     = require('miniz')
local path      = require('path')

local exports = {}

-------------------------------------------------------------------------------
-- BundleReader

---@class BundleReader
local BundleReader = core.Emitter:extend()
exports.BundleReader = BundleReader

---@param basePath string
function BundleReader:initialize(basePath)
    self.basePath = basePath
    self.files = {}

    self:open(basePath)
end

function BundleReader:open(basePath)
    if (not basePath) then
        return
    end

	local files = fs.readdirSync(basePath)
	if (not files) then
		return
	end

	local list = {}
	local listFiles

	listFiles = function(list, basePath, filename)
        local statInfo = fs.statSync(path.join(basePath, filename))
        -- print(basePath, filename, info.type)

		if (statInfo.type == 'directory') then
			-- list[#list + 1] = filename .. "/"

			local subfiles = fs.readdirSync(path.join(basePath, filename))
			if (not subfiles) then
				return
			end

			for _, file in ipairs(subfiles) do
				listFiles(list, basePath, path.join(filename, file))
			end

		else

			list[#list + 1] = filename
		end
	end

	for _, file in ipairs(files) do
		listFiles(list, basePath, file)
	end

	self.files = list or {}
end

function BundleReader:close()
	self.files = {}
	self.basePath = nil
end

---@param index integer
function BundleReader:extract(index)
	if (not self.files[index]) then
		return ''
	end

	local filename = path.join(self.basePath, self.files[index])
	return fs.readFileSync(filename) or ''
end

---@param filename string
function BundleReader:readFile(filename)
	local index = self:getIndex(filename)
	if (index) then
		return self:extract(index)
	end
end

---@param filename string
---@return integer
function BundleReader:getIndex(filename)
	for i = 1, #self.files do
		if (filename == self.files[i]) then
			return i
		end
	end
end

---@return integer
function BundleReader:getFileCount()
	return #self.files
end

---@param index integer
---@return string
function BundleReader:getFilename(index)
	return self.files[index]
end

---@param index integer
---@return any
function BundleReader:stat(index)
	if (not self.files[index]) then
		return
	end

	local filename = path.join(self.basePath, self.files[index])
	local statInfo = fs.statSync(filename)
	statInfo.uncomp_size = statInfo.size
	return statInfo
end

---@param index integer
---@return boolean
function BundleReader:isDirectory(index)
	local filename = self.files[index]
	if (not filename) then
		return
	end

    -- console.log('filename', filename)
	return filename:endsWith('/')
end

---@param filename string
---@return BundleReader
function exports.openBundle(filename)
    if (not filename) or (type(filename) ~= 'string') then
        return nil, 'invalid filename'
    end

	local stat = fs.statSync(filename)
	if (not stat) then
		return nil, 'file not exists'
	end

	if (stat.type == 'directory') then
		local filedata = fs.readFileSync(path.join(filename, "package.json"))
		local packageInfo = json.parse(filedata)
		if (not packageInfo) then
			return nil, 'invalid bundle format'
		end

		--console.log(list)
		return BundleReader:new(filename)

	else
		return miniz.createReader(filename)
	end
end

return exports
