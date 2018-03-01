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

local exports = {}

local KBYTES = 1024
local MBYTES = 1024 * 1024
local GBYTES = 1024 * 1024 * 1024
local TBYTES = 1024 * 1024 * 1024 * 1024


-- Format the bytes number to human-readable string
function exports.formatBytes(bytes)
	bytes = tonumber(bytes)
	if (not bytes) then
		return
	end

	if (bytes < KBYTES) then
		return bytes .. " Bytes"

	elseif (bytes < MBYTES) then
		return exports.formatFloat(bytes / KBYTES) .. " KBytes"

	elseif (bytes < GBYTES) then
		return exports.formatFloat(bytes / MBYTES) .. " MBytes"

	elseif (bytes < TBYTES) then
		return exports.formatFloat(bytes / GBYTES) .. " GBytes"

	else
		return exports.formatFloat(bytes / TBYTES) .. " TBytes"
	end
end

-- Format the floating-point number
function exports.formatFloat(value, size)
	value = tonumber(value)
	if (not value) then
		return
	end
	
	return string.format("%." .. (size or 1) .. "f", value)
end

function exports.noop()

end

function exports.getSystemTarget()
	local platform = os.platform()
	local arch = os.arch()

    local conf = require('app/conf')
    local fs   = require('fs')
    local json = require('json')

    local filename = conf.rootPath .. '/package.json'
    local packageInfo = json.parse(fs.readFileSync(filename)) or {}
    local target = packageInfo.target or (arch .. "-" .. platform)
    target = target:trim()
    return target
end

-- ┌┬ └┴┐─┘│

function exports.table(cols)
	local object = {}
	object.line = function(ch)
		ch = ch or '-'

		local list = {}
		for i = 1, #cols do
			local count = math.max(0, cols[i] - 2)
			list[#list + 1] = ' '
			list[#list + 1] = string.rep(ch, count)
		end

		print(table.concat(list))
	end

	object.title = function(title)
		local total = 0
		for i = 1, #cols do
			total = total + cols[i] + 1
		end

		local line = ' ' .. string.padRight(title, total - 3) .. ' '
		print(line)		
	end

	object.cell = function(...)
		local values = { ... }
		local line = {}

		for i = 1, #cols do
	        local colWidth = cols[i] - 2
	        local value = tostring(values[i])
			line[#line + 1] = ' '
			line[#line + 1] = string.padRight(value, colWidth, colWidth)
		end

		print(table.concat(line))		
	end	

	return object
end

return exports
