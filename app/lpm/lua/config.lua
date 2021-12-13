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

local json		= require('json')
local conf		= require('app/conf')

local config = {}

local function getProfile(key)
	local pos = key:find(':')
	local module = nil
	if (pos) then
		module = key:sub(1, pos - 1)
		key = key:sub(pos + 1)
	end

	return conf(module or 'user'), key
end

-- 打印指定名称的配置参数项的值
function config.get(key)
	if (not key) then
		print("\nError: missing required argument `key`.")
		print('\nUsage: lpm get <key>')
		return
	end

	local profile, name = getProfile(key)
	if (name == '*') then
		console.printr(profile.settings)

	else
		console.printr(profile:get(name))
	end
end

function config.help()
	local text = [[

Manage the lpm configuration files

Usage:
  lpm config get <key>         - Get value for <key>.
  lpm config list              - List all config files
  lpm config set <key> <value> - Sets the specified config <key> <value>.
  lpm config setjson <key> <json> - Sets the specified config <key> <json>.
  lpm config unset <key>       - Clears the specified config <key>.
  lpm get <key>                - Get value for <key>.
  lpm set <key> <value>        - Sets the specified config <key> <value>.

Aliases: c, conf

]]

	print(console.colorful(text))
end

function config.list(name)
	if (not name) then
		name = 'user'
	end

	local profile = conf(name)

	print(profile.filename .. ': ')
	console.printr(profile.settings)
end

-- 设置指定名称的配置参数项的值
function config.set(key, value)
	if (not key) or (not value) then
		print("\nError: missing required argument `key` and `value`.")
		print('\nUsage: lpm set <key> <value>')
		return
	end

	local profile, name = getProfile(key)
	local oldValue = profile:get(name)
	if (not oldValue) or (value ~= oldValue) then
		profile:set(name, value)
		profile:commit()
	end

	print('set `' .. tostring(name) .. '` = `' .. tostring(value) .. '`')
end

function config.setjson(key, value)
	if (not key) or (not value) then
		print("\nError: missing required argument `key` and `value`.")
		print('\nUsage: lpm set <key> <value>')
		return
	end

	value = json.parse(value)
	if (value == nil) then
		print('Invalid JSON text')
		return
	end

	local profile, name = getProfile(key)
	local oldValue = profile:get(name)
	if (not oldValue) or (value ~= oldValue) then
		profile:set(name, value)
		profile:commit()
	end

	print('set `' .. tostring(name) .. '` = `' .. tostring(value) .. '`')
end

-- 删除指定名称的配置参数项的值
function config.unset(key)
	if (not key) then
		print("\nError: missing required argument `key`.")
		print('\nUsage: lpm config unset <key>')
		return
	end

	local profile, name = getProfile(key)
	if (profile:set(name, nil)) then
		profile:commit()

		print('unset `' .. tostring(name) .. '`')
	end
end

return config
