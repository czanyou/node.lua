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
local cjson = require('cjson')
local util = require('util')

local meta = {
	description = "JSON module for lnode"
}

local exports = { meta = meta }

-------------------------------------------------------------------------------
-- encode

local _encodeTokenTable = {
	['\\'] = '\\\\',
	['"'] = '\\"',
	['\a'] = '\\a',
	['\b'] = '\\b',
	['\t'] = '\\t',
	['\n'] = '\\n',
	['\v'] = '\\v',
	['\f'] = '\\f',
	['\r'] = '\\r'
}

local _encodeLuaString, _encodeLuaValue, _encodeLuaTable

--[[
The escape function used by querystring.stringify, provided so that it could be
overridden if necessary.
--]]
function _encodeLuaString(str)
    if not str then
    	return str
    end

    str = str:gsub('([^%w])', function(c)
    	return _encodeTokenTable[c] or c

    	--return c
        --return string.format('%%%02X', string.byte(c))
    end)

    return str
end

function _encodeLuaValue(sb, value, indent)
	if (value == nil) then
		sb:append("null")

	elseif (type(value) == 'string') then
		value = _encodeLuaString(value)
		sb:append('"'):append(value):append('"')

	elseif (type(value) == 'number') then
		sb:append(value)

	elseif (type(value) == 'boolean') then
		if (value) then
			sb:append('true')
		else
			sb:append('false')	
		end

	elseif (type(value) == 'table') then
		_encodeLuaTable(sb, value, indent)
			
	else
		sb:append("null")
	end
end

function _encodeLuaTable(sb, object, indent)
	if (not indent) then
		indent = ""
	end

	local nextIndent = indent .. "  "
	local sep = ""

	if (#object > 0) then
		sb:append("[\n")
		
		for k,v in ipairs(object) do
			sb:append(sep)
			sb:append(nextIndent)
			_encodeLuaValue(sb, v, nextIndent)
			sep = ",\n"
		end

		if (#sep == 0) then
			sb:append("]\n")

		else
			sb:append("\n")
			sb:append(indent)
			sb:append("]")
		end

	else
		local keys = {}
		for k,v in pairs(object) do
			table.insert(keys, k)
		end

		table.sort( keys, function(a, b) return tostring(a) < tostring(b) end)
	
		sb:append("{\n")
		for i = 1, #keys do
			local k = keys[i]
			local v = object[k]

			sb:append(sep)
			sb:append(nextIndent)
			sb:append('"')
			sb:append(k)
			sb:append('":')
			_encodeLuaValue(sb, v, nextIndent)

			sep = ",\n"
		end
		
		if (#sep == 0) then
			sb:append("}\n")

		else
			sb:append("\n")
			sb:append(indent)
			sb:append("}")
		end
	end
end

exports.stringify = function(value, test, indent)
    if (type(value) == 'table') and (next(value) == nil) then
        return "[]";
    end

    if (indent) then
        local sb = util.StringBuffer:new()
	    _encodeLuaTable(sb, value, "")
        return sb:toString()
    end

    local status, ret = pcall(cjson.encode, value)
    if (status) then
        return ret
    end

    --print("encode", status, ret)
    return nil, ret
end

exports.parse = function(data)
    local status, ret = pcall(cjson.decode, data)
    if (status) then
        return ret
    end

    --print("decode", status, ret)
    return nil, ret
end

exports.encode = exports.stringify
exports.decode = exports.parse
exports.null   = cjson.null

return exports
