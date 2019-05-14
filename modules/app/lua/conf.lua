--[[

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

local core 	= require("core")
local fs   	= require("fs")
local json  = require("json")
local path 	= require("path")
local util  = require('util')

local exports = {}

-------------------------------------------------------------------------------
-- search path

exports.rootPath = "/usr/local/lnode"
if (process.rootPath) then
	exports.rootPath = process.rootPath
end

local osType = os.platform()
if (osType == 'win32') then
	local pathname = path.dirname(process.execPath)
	exports.rootPath = path.dirname(pathname)
end

local function trimValue(value)
	local valueType = type(value)
	if (valueType == 'function') then
		return tostring(value)

	elseif (valueType == 'thread') then
		return tostring(value)

	elseif (valueType == 'userdata') then
		return tostring(value)

	elseif (valueType == 'table') then
		if (#value > 0) then
			for k, v in ipairs(value) do
				value[k] = trimValue(v)
			end

		else
			for k, v in pairs(value) do
				value[k] = trimValue(v)
			end
		end
	end

	return value
end

-------------------------------------------------------------------------------
-- Profile

local Profile = core.Emitter:extend()
exports.Profile = Profile

function Profile:initialize(filename, callback)
	self.filename = filename
	self:reload(callback)

	if (not self.settings) then
		self.settings = {}
	end
end

function Profile:commit(callback)
	local tempname = self.filename .. ".tmp"
	local data = self:toString()

	if (callback) then
		fs.writeFile(tempname, data, function(err)
			if (err) then
				callback(err)
				return
			end

			fs.stat(tempname, function(err, info)
				if (err) then
					callback(err)
					return
				end

				if info and (info.size == #data) then
					os.remove(self.filename)
					os.rename(tempname, self.filename)

					callback()
				else

					callback('commit error')
				end
			end)
		end)

	else
		fs.writeFileSync(tempname, data)
		local info = fs.statSync(tempname)
		if info and (info.size == #data) then
			os.remove(self.filename)
			os.rename(tempname, self.filename)
		end
	end
end

function Profile:get(key)
	if (key == nil) then
		return nil
	end

	key = tostring(key)
	if (key == nil) then
		return nil
	end

	local settings = self.settings or {}
	return settings[key]
end

function Profile:load(text)
	if (type(text) ~= "string") then
		return nil
	end

	local data = json.parse(text)
	if (type(data) ~= 'table') then
		return nil
	end

	self.settings = data
	return data
end

function Profile:reload(callback)
	if (not self.filename) then
		if callback then callback('file not found') end
		return nil, 'file not found'
	end

	if callback then
		fs.readFile(self.filename, function(err, text)
			if ((err) or (not text)) then
				callback(err or 'file not found')
				return
			end

			local ret = self:load(text)
			callback(nil, ret)
		end)

	else
		local text, err = fs.readFileSync(self.filename)
		if (not text) then
			return nil, err
		end

		return self:load(text)
	end
end

function Profile:set(key, value)
	if (key == nil) then
		return false
	end

	key = tostring(key)
	if (key == nil) then
		return false
	end

	if (type(self.settings) ~= 'table') then
		self.settings = {}
	end

	self.settings[key] = trimValue(value)
	return true
end

function Profile:toString()
	if (type(self.settings) == nil) then
		return
	end

	return json.stringify(self.settings)
end

function exports.load(name, callback)
	local await = util.await
	util.async(function()
		local err, ret

		local basePath = path.join(exports.rootPath, "conf")
		err, ret = await(fs.exists, basePath)
		if (err) or (not ret) then

			basePath = path.join(exports.rootPath, "bin")
			err, ret = await(fs.exists, basePath)
			if (err) or (not ret) then
				if callback then callback('file not found') end
				return
			end
		end

		local filename = path.join(basePath, name .. ".conf")
		--print(filename)
		local profile
		profile = Profile:new(filename, function()
			if callback then callback(nil, profile) end
		end)
	end)
end

setmetatable(exports, {
	__call = function(self, name, callback)
		if (not name) then
			return nil
		end

		if (callback) then
			self.load(name, callback)
			return
		end
		
		local basePath = path.join(exports.rootPath, "conf")
		if (not fs.existsSync(basePath)) then
			basePath = path.join(exports.rootPath, "bin")
		end

		if (not fs.existsSync(basePath)) then
			--print(basePath)
			return nil
		end

		local filename = path.join(basePath, name .. ".conf")
		--print(filename)
		return Profile:new(filename, callback)
	end
})

return exports
