--[[

Copyright 2015 The Luvit Authors. All Rights Reserved.
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
--[[
This module provides utilities for dealing with query strings. It provides 
the following methods:


--]]
local meta = { }
meta.name       = "lnode/querystring"
meta.version    = "1.0.2"
meta.license    = "Apache 2"
meta.description = "Node-style query-string codec for lnode"
meta.tags       = { "lnode", "url", "codec" }

local exports = { meta = meta }

--[[
The querystring.escape() method performs URL percent-encoding on the given str 
in a manner that is optimized for the specific requirements of URL query strings.

The querystring.escape() method is used by querystring.stringify() and is 
generally not expected to be used directly. It is exported primarily to allow 
application code to provide a replacement percent-encoding implementation if 
necessary by assigning querystring.escape to an alternative function.
--]]
function exports.escape(str)
    if str then
        str = str:gsub('\n', '\r\n')
        str = str:gsub('([^%w])', function(c)
            return string.format('%%%02X', string.byte(c))
        end )
    end
    return str
end

--[[
Parse querystring into table. urldecode tokens

Deserialize a query string to an object. Optionally override the default 
separator ('&') and assignment ('=') characters.

Options object may contain maxKeys property (equal to 1000 by default), it'll 
be used to limit processed keys. Set it to 0 to remove key count limitation.

Options object may contain decodeURIComponent property (querystring.unescape 
by default), it can be used to decode a non-utf8 encoding string if necessary.
--]]
function exports.parse(str, sep, eq, options)
    if (not str) then
        return nil
    end

    if not sep then sep = '&' end
    if not eq  then eq  = '=' end
    str = tostring(str)

    local maxKeys  = 1000
    local unescape = exports.unescape
    if (options) then
        unescape = options.decodeURIComponent or unescape
        maxKeys  = options.maxKeys or maxKeys
    end

    local index = 0
    local vars = { }
    for pair in str:gmatch('[^' .. sep .. ']+') do
        index = index + 1
        if (maxKeys > 0) and (index > maxKeys) then
            break
        end

        if not pair:find(eq) then
            vars[unescape(pair)] = ''

        else
            local key, value = pair:match('([^' .. eq .. ']*)' .. eq .. '(.*)')
            if key then
                key   = unescape(key:trim())
                value = unescape(value)
                local valueType = type(vars[key])
                if valueType == 'nil' then
                    vars[key] = value

                elseif valueType == 'table' then
                    table.insert(vars[key], value)

                else
                    vars[key] = { vars[key], value }
                end
            end
        end
    end

    return vars
end

--[[
Serialize an object to a query string. Optionally override the default separator 
('&') and assignment ('=') characters.

Options object may contain encodeURIComponent property (querystring.escape by 
default), it can be used to encode string with non-utf8 encoding if necessary.
--]]
function exports.stringify(params, sep, eq, options)
    if (not params) or (type(params) ~= "table") then
        return ''
    end

    if not sep then sep = '&' end
    if not eq  then eq  = '=' end

    local escape = exports.escape
    if (options) then
        escape = options.encodeURIComponent or escape 
    end

    local fields = { }
    for key, value in pairs(params) do
        local keyString = escape(tostring(key)) .. eq
        if type(value) == "table" then
            for _, v in ipairs(value) do
                table.insert(fields, keyString .. escape(tostring(v)))
            end
        else
            table.insert(fields, keyString .. escape(tostring(value)))
        end
    end
    return table.concat(fields, sep)
end

--[[
The querystring.unescape() method performs decoding of URL percent-encoded 
characters on the given str.

The querystring.unescape() method is used by querystring.parse() and is 
generally not expected to be used directly. It is exported primarily to allow 
application code to provide a replacement decoding implementation if necessary 
by assigning querystring.unescape to an alternative function.

--]]
function exports.unescape(str)
    if (not str) then
        return str
    end
    
    str = str:gsub('+', ' ')
    str = str:gsub('%%(%x%x)', function(h)
        return string.char(tonumber(h, 16))
    end )
    str = str:gsub('\r\n', '\n')
    return str
end

exports.urlencode = exports.escape
exports.urldecode = exports.unescape

return exports
