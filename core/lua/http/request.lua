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

local meta = { }
meta.name        = "request"
meta.version     = "1.0.0"
meta.description = "Simplified HTTP client."
meta.tags        = { "request", "http", "client" }

local fs    = require('fs')
local http  = require('http')
local url   = require('url')
local timer = require('timer')
local json  = require('json')

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

            sb:append('\r\n--'):append(boundaryKey):append('\r\n')
            sb:append('Content-Disposition: form-data')
            sb:append('; name="'):append(key):append('"')
            sb:append('; filename="'):append(filename):append('"')
            sb:append('\r\n')
            sb:append('Content-Type: '):append(contentType):append('\r\n')
            sb:append('\r\n')
            sb:append(filedata)

        else
            sb:append('\r\n--'):append(boundaryKey):append('\r\n')
            sb:append('Content-Disposition: form-data')
            sb:append('; name="'):append(key):append('"')
            sb:append('\r\n\r\n')
            sb:append(file)
        end
    end

    -- end of stream
    sb:append('\r\n--'):append(boundaryKey):append('--')

    return sb:toString()
end

-------------------------------------------------------------------------------
-- exports

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

    --print('url', url)
    local request = http.get(urlString, function(response)

        local contentLength = tonumber(response.headers['Content-Length']) or 0

        callback(nil, 0, response)

        local percent = 0
        local downloadLength = 0
        local data = {}
        local lastTime = timer.now()

        response:on('data', function(chunk)
            if (not chunk) then
                return
            end

            --printr("ondata", {chunk=chunk})
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

        response:on('end', function()
            if (response.statusCode ~= 200) then
                --console.log(response)
                callback('Download failed: ' .. (response.statusMessage or ''))
                return
            end

            response.body = table.concat(data)
            callback(nil, 100, response, response.body)
        end)

        response:on('error', function(err)
            callback('Download failed: ' .. (err or ''))
        end)
    end)

    request:on('error', function(err)
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

    local request = exports.request(urlString, args, callback)
    request:done()
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

    local postLength = 0
    if (postData) then
        postLength = #postData
    end

    headers['Content-Length'] = postLength

    local args = { method  = options.method or 'POST', headers = headers }
    local request = exports.request(urlString, args, callback)

    if (postLength < 1024 * 1024) or (not options.percent) then
        if (postLength > 0) then
            request:write(postData)
        end

        request:done()
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
                request:done()
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

    -- recv
    local responseBody = {}
    request = http.request(options, function(response)
        response:on('data', function(data)
            responseBody[#responseBody + 1] = data
        end)

        response:on('end', function()
            local content = table.concat(responseBody)
            clearTimeout(timeoutTimer)

            callback(nil, response, content)
            request:destroy()
        end)
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

    local args = {}
    if (options.filename) then
        local filename = options.filename
        local filedata = options.filedata or fs.readFileSync(filename)
        if (not filedata) then
            print('File not found: ' .. tostring(filename))
            callback('File not found: ')
            return
        end

        local files = {file = { name = filename, data = filedata } }
        args.files = files

    elseif (options.files) then
        args.files = options.files

    else

        args.data = options.data
    end

    args.percent = function(offset, total)
        local percent = 0
        if (total) and (total > 0) then
            percent = math.floor(offset * 100 / total)
        end

        if (percent < 100) then
            callback(nil, percent)
        end
    end

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
