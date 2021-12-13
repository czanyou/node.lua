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

local meta = {
    description = "Simplified HTTP client."
}

local fs    = require('fs')
local http  = require('http')
local url   = require('url')
local timer = require('timer')
local json  = require('json')
local util  = require('util')

local querystring   = require('querystring')

-- Simplified HTTP client
-- ======
--
-- 一个轻量级的易于使用的 HTTP 请求客户端
--
local exports = { meta = meta }

-------------------------------------------------------------------------------
-- local functions

local boundaryKey = "vision-34abcd234mlmnz365"

local function getFormData(files)
    local sb = StringBuffer:new()

    for key, file in pairs(files) do
        if (type(file) == 'table') then
            local filedata = file.data
            local filename = file.name or 'file'
            local contentType = file.contentType or 'application/octet-stream'

            sb:append('--'):append(boundaryKey):append('\r\n')
            sb:append('Content-Disposition: form-data')
            sb:append('; name="'):append(key):append('"')
            sb:append('; filename="'):append(filename):append('"')
            sb:append('\r\n')
            sb:append('Content-Type: '):append(contentType):append('\r\n')
            sb:append('\r\n')
            sb:append(filedata)
            sb:append('\r\n')

        else
            sb:append('\r\n--'):append(boundaryKey):append('\r\n')
            sb:append('Content-Disposition: form-data')
            sb:append('; name="'):append(key):append('"')
            sb:append('\r\n\r\n')
            sb:append(file)
            sb:append('\r\n')
        end
    end

    -- end of stream
    sb:append('--'):append(boundaryKey):append('--')

    return sb:toString()
end

local function _hash(token1, token2, token3, token4, token5, token6)
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

    if (token4) then
        sb:append(':')
        sb:append(token4)
    end

    if (token5) then
        sb:append(':')
        sb:append(token5)
    end

    if (token6) then
        sb:append(':')
        sb:append(token6)
    end

    local value = sb:toString()
    local result = util.md5string(value):lower()
    -- console.log('_hash', value, result)
    return result
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
-- exports

function exports.getAuthorization(params)
    local sb = StringBuffer:new()

    if (params.METHOD == 'Basic') then
        sb:append(params.METHOD):append(' ')

        local ha = params.username .. ':' .. params.password;
        local response = util.base64Encode(ha);
        sb:append(response)

    elseif (params.METHOD == 'X-Digest') then
        local uriString = params.uriString or params.path or ''
        sb:append(params.METHOD):append(' ')
        sb:append('username="'):append(params.username  or ''):append('", ')
        sb:append('realm="'):append(params.realm or ''):append('", ')
        sb:append('nonce="'):append(params.nonce or ''):append('", ')
        sb:append('uri="'):append(uriString or ''):append('", ')

        if (params.opaque) then
            sb:append('opaque="'):append(params.opaque  or ''):append('", ')
        end

        if (not params.qop) then
            params.qop = 'auth'
        end

        if (not params.nc) then
            params.nc = '00000002'
        end

        if (not params.cnonce) then
            params.cnonce = util.randomString(8)
        end

        sb:append('qop='):append(params.qop  or ''):append(', ')
        sb:append('nc='):append(params.nc or ''):append(', ')
        sb:append('cnonce="'):append(params.cnonce or ''):append('", ')
        

        local ha1 = _hash(params.username, params.realm, params.password)
        local ha2 = _hash(params.method, uriString)
        local ha3 = _hash(ha1, params.nonce, params.nc, params.cnonce, params.qop, ha2)

        sb:append('response="'):append(ha3 or ''):append('"')

    else
        local uriString = params.uriString or params.path or ''
        sb:append(params.METHOD):append(' ')
        sb:append('username="'):append(params.username  or ''):append('", ')
        sb:append('realm="'):append(params.realm or ''):append('", ')
        sb:append('nonce="'):append(params.nonce or ''):append('", ')

        if (params.cnonce) then
            sb:append('cnonce="'):append(params.cnonce or ''):append('", ')
        end

        if (params.nc) then
            sb:append('nc="'):append(params.nc or ''):append('", ')
        end

        sb:append('uri="'):append(uriString or ''):append('", ')

        local ha1 = _hash(params.username, params.realm, params.password)
        local ha2 = _hash(params.method, uriString)
        local ha3 = _hash(ha1, params.nonce, ha2)

        sb:append('response="'):append(ha3 or ''):append('"')
    end

    return sb:toString()
end

function exports.delete(urlString, options, callback)
    options = options or {}
    options.method = 'DELETE'
    return exports.post(urlString, options, callback)
end

-- Download the system update package file
-- callback(err, percent, data)
function exports.download(urlString, options, callback)
    callback = callback or function() end
    options  = options  or {}

    if (type(options) == 'function') then
        callback, options = options, nil
    end

    local function onReponse(response)
        local contentLength = tonumber(response.headers['Content-Length']) or 0
        -- console.log(response.statusCode, response, contentLength)

        callback(nil, 0, response)

        local percent = 0
        local downloadLength = 0
        local data = {}
        local lastTime = timer.now()

        response:on('data', function(chunk)
            if (not chunk) then
                return
            end

            -- console.log("http.data", {chunk=chunk})
            table.insert(data, chunk)
            downloadLength = downloadLength + #chunk

            -- thread.sleep(100)

            if (downloadLength < contentLength) then
                percent = math.floor(downloadLength * 100 / contentLength)

                local now = timer.now()
                if ((now - lastTime) >= 500) or (contentLength == downloadLength) then
                    lastTime = now
                    callback(nil, percent)
                end
            end
        end)

        response:once('end', function()
            response.body = table.concat(data)
            callback(nil, 100, response, response.body)
        end)

        response:once('error', function(err)
            callback('Download failed: ' .. (err or ''))
        end)
    end

    --print('url', url)
    local request = http.get(urlString, function(response)
        if (response.statusCode == 401) then

            local urlObject = url.parse(urlString)
            local auth = urlObject.auth
            if (auth) then
                local index = string.find(auth, ':')
                if (index) then
                    urlObject.username = string.sub(auth, 1, index - 1)
                    urlObject.password = string.sub(auth, index + 1)
                end
            end

            --console.log(urlObject)

            local headers = {}
            local requestOptions = { headers = headers }
            requestOptions.host = urlObject.host
            requestOptions.path = urlObject.path
            requestOptions.port = urlObject.port

            local authenticate = response.headers['WWW-Authenticate']
            authenticate = authenticate and exports.parseAuthenticate(authenticate)

            --console.log(authenticate)

            if (authenticate) then
                local params = authenticate
                params.method = 'GET'
                params.username = options.username or urlObject.username
                params.password = options.password or urlObject.password
                params.uriString = urlObject.path
                headers.Authorization = exports.getAuthorization(params)
            end

            --console.log(headers)

            request = http.get(requestOptions, function(response)
                if (response.statusCode >= 300) then
                    callback('Download failed: ' .. (response.statusMessage or ''))
                    return
                end

                onReponse(response)
            end)
            
            return

        elseif (response.statusCode >= 300) then
            callback('Download failed: ' .. (response.statusMessage or ''))
            return
        end

        onReponse(response)
    end)

    request:once('error', function(err)
        callback('Download failed: ' .. (err or ''))
    end)
end

function exports.get(urlString, options, callback)
    -- get(url, callback)
    if (type(options) == 'function') then
        callback = options;
        options = nil;
    end

    local headers = (options and options.headers) or {}
    local args = { method  = 'GET', headers = headers }

    if (options and options.username) then
        local params = {
            METHOD = 'Basic',
            method = 'GET',
            username = options.username,
            password = options.password
        }
        headers.Authorization = exports.getAuthorization(params)
    end

    local request = exports.request(urlString, args, callback)
    request:finish()
end

---@param value string
function exports.parseAuthenticate(value)
    local pos, _ = value:find(' ')
    --print('value', s, n)
    if (not pos) then
        return nil
    end

    local method = value:sub(1, pos - 1)
    value = value:sub(pos + 1)

    local params = {}

    --print('value', method, value)
    local tokens = value:split(",")
    for _, v in pairs(tokens) do
        local start, _ = v:find('=')
        if (start) then
            local key = v:sub(1, start - 1):trim()
            local data = _parseQString(v:sub(start + 1):trim())

            params[key] = data
        end
    end

    params.METHOD = method
    return params
end

function exports.post(urlString, options, callback)
    options = options  or {}

    local postData = nil
    local headers = options.headers or {}
    local contentType

    if (options.form) then
        postData = querystring.stringify(options.form or {})
        contentType = 'application/x-www-form-urlencoded'

    elseif (options.formData) then
        postData = options.formData

        local boundary = options.boundaryKey or boundaryKey
        contentType = 'multipart/form-data; boundary=' .. boundary

    elseif (options.files) then
        postData = getFormData(options.files)

        local boundary = options.boundaryKey or boundaryKey
        contentType = 'multipart/form-data; boundary=' .. boundary

        -- console.log(postData, contentType);

    elseif (options.data) then
        postData = options.data
        contentType = 'application/octet-stream'

    elseif (options.json) then
        postData = options.json
        if (type(postData) ~= 'string') then
            postData = json.stringify(postData)
        end
        contentType = 'application/json'
    end

    if (not headers['Content-Type']) then
        headers['Content-Type'] = options.contentType or contentType
    end

    if (options and options.authenticate) then
        local params = options.authenticate
        params.method = 'POST'
        headers.Authorization = exports.getAuthorization(params)
    end

    local postLength = 0
    if (postData) then
        postLength = #postData
    end

    headers['Content-Length'] = postLength
    -- console.log('headers', headers)

    local args = { method  = options.method or 'POST', headers = headers }
    local request = exports.request(urlString, args, callback)

    if (postLength < 1024 * 1024) or (not options.percent) then
        if (postLength > 0) then
            request:write(postData)
        end

        request:finish()
        return
    end

    -- if options.percent
    local offset = 1
    local size = 1024 * 16

    --console.log('request', request)
    request:on('socket', function(socket)
        request:uncork()

        local onSend = function()
            if (offset > postLength) then
                return
            end

            while (true) do
                local data = postData:sub(offset, offset + size - 1)
                if (not data) or (#data <= 0) then
                    break
                end

                offset = offset + #data

                --require('thread').sleep(10)
                local ret = request:write(data)
                if (not ret) then
                    break
                end
            end

            options.percent(offset, postLength)

            if (offset > #postData) then
                request:finish()
            end
        end

        request:on('drain', function()
            onSend()
        end)

        onSend()

    end)
end

function exports.put(urlString, options, callback)
    options = options or {}
    options.method = 'PUT'
    return exports.post(urlString, options, callback)
end

function exports.request(urlString, options, callback)
    if (type(options) == 'function') then
        callback = options
        options  = nil
    end

    callback = callback or function() end
    options  = options  or {}

    -- url
    local urlObject = url.parse(urlString)
    if (urlObject) then
        options.host    = urlObject.host or '127.0.0.1'
        options.port    = urlObject.port or 80
        options.path    = urlObject.path or '/'
    end

    local request = nil

    local timeout = options.timeout or 20000
    local timeoutTimer = nil

    timeoutTimer = setTimeout(timeout, function()
        request:destroy()
        callback('Timeout')
    end)

    local responseBody = {}
    local function onResponse(response)
        response:on('data', function(data)
            responseBody[#responseBody + 1] = data
        end)

        response:on('end', function()
            local content = table.concat(responseBody)
            clearTimeout(timeoutTimer)

            callback(nil, response, content)
            request:destroy()
        end)

    end

    -- recv
    request = http.request(options, function(response)
        if (response.statusCode == 401) then
            console.log(response.headers)
            return
        end

        onResponse(response)
    end)

    -- error
    request:on('error', function(error, ...)
        --console.log('error', error, ...)
        clearTimeout(timeoutTimer)

        callback(error)
    end)

    --console.log('request', request)
    return request
end

function exports.upload(urlString, options, callback)
    if (type(callback) ~= 'function') then
        callback = function() end
    end

    options  = options  or {}

    -- files
    local args = {}
    if (options.filename) then
        local filename = options.filename
        local filedata = options.filedata or fs.readFileSync(filename)
        if (not filedata) then
            print('File not found: ' .. tostring(filename))
            callback('File not found: ')
            return
        end

        local files = { file = { name = filename, data = filedata } }
        args.files = files

    elseif (options.files) then
        args.files = options.files

    else
        args.data = options.data
    end

    -- progress
    args.percent = function(offset, total)
        local percent = 0
        if (total) and (total > 0) then
            percent = math.floor(offset * 100 / total)
        end

        if (percent < 100) then
            callback(nil, percent)
        end
    end

    -- post
    args.headers = options.headers
    -- console.log('args', args)
    exports.post(urlString, args, function(err, response, body)
        if (err) then
            callback(err)
            return

        elseif (response.statusCode ~= 200) then
            callback(response.statusCode .. ': ' .. tostring(response.statusMessage))
            return
        end

        callback(nil, 100, response, body)
    end)
end

setmetatable( exports, {
    __call = function(self, ...)
        return self.get(...)
    end
})

return exports
