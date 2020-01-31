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
local core   = require('core')
local utils  = require('util')

local meta 		= { }
local exports 	= { meta = meta }

-------------------------------------------------------------------------------
-- Methods

-- 常见的 RTSP 方法
exports.METHODS = {
  'ANNOUNCE',
  'DESCRIBE',
  'GET_PARAMETER',
  'OPTIONS',
  'PAUSE',
  'PLAY',
  'RECORD',
  'REDIRECT',
  'SET_PARAMETER',
  'SETUP',
  'TEARDOWN'
}

-------------------------------------------------------------------------------
-- Status Codes

-- 常见的 RTSP 状态码
local STATUS_CODES = {
    [100] = 'Continue',
    [101] = 'Switching Protocols',
    [102] = 'Processing',

    [200] = 'OK',
    [201] = 'Created',                          -- RECORD
    [250] = 'Low on Storage Space',             -- RECORD

    -- RFC 4918
    [300] = 'Multiple Choices',
    [301] = 'Moved Permanently',
    [302] = 'Moved Temporarily',
    [303] = 'See Other',
    [304] = 'Not Modified',

    [400] = 'Bad Request',
    [401] = 'Unauthorized',
    [402] = 'Payment Required',
    [403] = 'Forbidden',
    [404] = 'Not Found',

    [405] = 'Method Not Allowed',
    [406] = 'Not Acceptable',
    [407] = 'Proxy Authentication Required',
    [408] = 'Request Time-out',
    [409] = 'Conflict',

    [410] = 'Gone',
    [411] = 'Length Required',
    [412] = 'Precondition Failed',              -- DESCRIBE, SETUP
    [413] = 'Request Entity Too Large',
    [414] = 'Request-URI Too Large',

    [415] = 'Unsupported Media Type',
    [451] = 'Invalid parameter',                -- SETUP
    [452] = 'Illegal Conference Identifier',    -- SETUP
    [453] = 'Not Enough Bandwidth',             -- SETUP
    [454] = 'Session Not Found',

    [455] = 'Method Not Valid In This State',
    [456] = 'Header Field Not Valid',
    [457] = 'Invalid Range',                    -- PLAY
    [458] = 'Parameter Is Read-Only',           -- SET_PARAMETER
    [459] = 'Aggregate Operation Not Allowed',

    [460] = 'Only Aggregate Operation Allowed',
    [461] = 'Unsupported Transport',
    [462] = 'Destination Unreachable',    

    [500] = 'Internal Server Error',
    [501] = 'Not Implemented',
    [502] = 'Bad Gateway',
    [503] = 'Service Unavailable',
    [504] = 'Gateway Time-out',

    [505] = 'RTSP Version not supported',
    [551] = 'Option not support'
}

exports.STATUS_CODES    = STATUS_CODES
exports.realm           = "rtspd"
exports.nonce           = "66bb9f0bf5ac93a909ac8e88877ae727"

-------------------------------------------------------------------------------

local function _hash(token1, token2, token3)
    local sb = StringBuffer:new()
    sb:append(token1)

    if (token2) then
        sb:append(':')
        sb:append(token2)
    end

    if (token3) then
        sb:append(':')
        sb:append(token3)
    end

    return utils.md5string(sb:toString()):lower()
end

local function _parseQString(value)
    if (type(value)  ~= 'string') then
        return ""
    end

    if (value:byte(1) ~= 34) then
        return value
    end

    local s, n = value:find('"', 2)
    if (s) then
        value = value:sub(2, s - 1)
    end
    
    return value or ""
end

-------------------------------------------------------------------------------
-- RtspHeaderMeta

-- Provide a nice case insensitive interface to headers.
local RtspHeaderMeta = {
    __index = function(list, name)
        if type(name) ~= "string" then
            return rawget(list, name)
        end

        name = name:lower()
        for i = 1, #list do
            local key, value = table.unpack(list[i])
            if key:lower() == name then return value end
        end
    end,

    __newindex = function(list, name, value)
        -- non-string keys go through as-is.
        if (not name) then
            return
        elseif type(name) ~= "string" then
            return rawset(list, name, value)
        end

        -- First remove any existing pairs with matching key
        local lowerName = name:lower()
        for i = #list, 1, -1 do
            if list[i][1]:lower() == lowerName then
                table.remove(list, i)
            end
        end

        -- If value is nil, we're done
        if value == nil then return end
        -- Otherwise, set the key(s)

        if (type(value) == "table") then
            -- We accept a table of strings
            for i = 1, #value do
                rawset(list, #list + 1, { name, tostring(value[i]) })
            end
        else
            -- Or a single value interperted as string
            rawset(list, #list + 1, { name, tostring(value) })
        end
    end,
}

exports.RtspHeaderMeta = RtspHeaderMeta

-------------------------------------------------------------------------------
-- RtspMessage

local RtspMessage = core.Object:extend()
exports.RtspMessage = RtspMessage

function RtspMessage:initialize()
    local headers = setmetatable({}, RtspHeaderMeta)

    self.headers        = headers
    self.method         = nil
    self.path           = nil
    self.scheme         = "RTSP"
    self.statusCode     = nil
    self.statusMessage  = nil
    self.version        = 1.0
end

function RtspMessage:checkAuthorization(request, callback)
    local value = request:getHeader('Authorization')
    if (value) then
        local params = exports.parseAuthenticate(value)
        local username = params.username
        local password = callback(username)

        local ha1 = _hash(username, params.realm, password)
        local ha2 = _hash(request.method, request.uriString)
        local response = _hash(ha1, params.nonce, ha2)

        if (response == params.response) then
            self:removeHeader('WWW-Authenticate')
            self:setStatusCode(200)
            return true
        end
    end

    local sb = StringBuffer:new()
    sb:append('Digest'):append(' ')
    sb:append('realm="'):append(exports.realm or ''):append('", ')
    sb:append('nonce="'):append(exports.nonce or ''):append('", ')
    sb:append('stale='):append('"FALSE"')

    self:setHeader('WWW-Authenticate', sb:toString())
    self:setStatusCode(401)

    return false
end

function RtspMessage:getHeader(name)
    return self.headers[name]
end

function RtspMessage:removeHeader(name)
    self.headers[name] = nil
end

function RtspMessage:setAuthorization(params, username, password)
    local sb = StringBuffer:new()

    if (params.METHOD == 'Basic') then
        sb:append(params.METHOD):append(' ')

        local ha = username .. ':' .. password;
        local response = utils.base64Encode(ha);
        sb:append(response)

    else
        sb:append(params.METHOD):append(' ')
        sb:append('username="'):append(username  or ''):append('", ')
        sb:append('realm="'):append(params.realm or ''):append('", ')
        sb:append('nonce="'):append(params.nonce or ''):append('", ')
        sb:append('uri="'):append(self.uriString or ''):append('", ')

        local ha1 = _hash(username, params.realm, password)
        local ha2 = _hash(self.method, self.uriString)
        local ha3 = _hash(ha1, params.nonce, ha2)

        sb:append('response="'):append(ha3 or ''):append('"')
    end

    self:setHeader('Authorization', sb:toString())
end

function RtspMessage:setHeader(name, value)
    self.headers[name] = value
end

function RtspMessage:setStatusCode(statusCode, statusMessage)
    self.statusCode    = statusCode   or 200
    self.statusMessage = statusMessage or STATUS_CODES[self.statusCode] or 'OK'
end

-------------------------------------------------------------------------------
-- exports

function exports.newDateHeader(time)
    return os.date("%a, %d %b %Y %H:%M:%S GMT", time or os.time())
end

function exports.newRequest(method, path)
    local request = RtspMessage:new()
    request.method  = method or 'OPTIONS'
    request.path    = path or '/'
    request.version = 1.0
    return request
end

function exports.newResponse(statusCode, statusMessage)
    local response = RtspMessage:new()
    response.statusCode     = statusCode or 200
    response.statusMessage  = statusMessage or STATUS_CODES[statusCode] or 'OK'
    response.version        = 1.0
    return response
end

function exports.parseAuthenticate(value)
    local s, n = value:find(' ')
    --print('value', s, n)
    if (not s) then
        return nil
    end

    local method = value:sub(1, s - 1)
    value = value:sub(s + 1)

    local params = {}

    --print('value', method, value)
    local tokens = value:split(",")
    for _, v in pairs(tokens) do
        local s, n = v:find('=')
        if (s) then
            local key = v:sub(1, s - 1):trim()
            local data = _parseQString(v:sub(s + 1):trim())

            params[key] = data
        end
    end

    params.METHOD = method
    return params
end

return exports

