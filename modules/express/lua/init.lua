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

local core 	= require('core')
local utils = require('util')
local http 	= require('http')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local mime 	= require('express/mime')
local formdata = require('express/formdata')

local querystring  = require('querystring')

local ServerResponse  = http.ServerResponse
local IncomingMessage = http.IncomingMessage

local exports = { }
local IncomingCounter = 0

function exports.checkHttpSessions()
    local now = Date.now()
    local httpSessions = exports.httpSessions
    if (not httpSessions) then
        return
    end

    for sessionId, httpSession in pairs(httpSessions) do
        local span = now - (httpSession.updated or 0)
        if (span > 10 * 60 * 1000) then
            httpSessions[sessionId] = nil
        end
    end
end

function exports.startHttpSessions()
    if (exports.httpSessions) then
        return
    end

    exports.httpSessions = {}

    exports.httpSessionTimer = setInterval(1000 * 10, function()
        exports.checkHttpSessions()
    end)
end

local function _getContentType(path)
    return mime[path:lower():match("[^.]*$")] or mime.default
end

local function _getFileList(path, contextPath)
    local data = utils.StringBuffer:new()
    data:append('<!DOCTYPE html>\r\n')
    data:append('<html><head><meta http-equiv="content-type" content="text/html;charset=utf-8"></head>\r\n<body>')
    data:append('<h1>Path: '):append(contextPath):append('</h1><hr/>')
    data:append('<table>')
    data:append('<tr><td>Name</td></tr>')

    if (contextPath == '/') then
        contextPath = ''
    end

    for k,v in fs.scandirSync(path) do
        data:append('<tr>')
        data:append('<td><a href="' .. contextPath .. '/' .. k .. '" class="' .. v .. '">')
        --console.log(k, v)
        data:append(k)
        data:append('</a></td>')
        data:append('</tr>\r\n')
    end

    data:append('</table>\r\n')
    data:append('</body></html>')

    return data:toString()
end

-------------------------------------------------------------------------------
-- IncomingMessage

function IncomingMessage:getSessionId()
    local cookie = self.headers['Cookie']
    local sessionId = nil

    if (cookie) then
        cookie = querystring.parse(cookie, ';', '=')

        if (cookie) then
            sessionId = cookie['LSESSIONID']
        end
    end

    return sessionId
end

function IncomingMessage:getSession(create)
    local httpSessions = exports.httpSessions or {}
    local sessionId = self:getSessionId()
    local httpSession = sessionId and httpSessions[sessionId]
    if (not httpSession) and create then
        httpSession = {}
        httpSessions[sessionId] = httpSession
    end

    if (httpSession) then
        httpSession.updated = Date.now()
    end

    return httpSession
end

function IncomingMessage:get(field)
    if (field) then
        return self.headers[field]
    end
end

function IncomingMessage:readBody(callback)
    if (self.body ~= nil) then
        return
    end

    local contentType = self:get('Content-Type')
    if (contentType) then
        local tokens = contentType:split(';')
        contentType = tokens[1]
    end

    local sb = StringBuffer:new()

    self:on('data', function(data)
        sb:append(data)

        --console.log('data', contentType)
        --console.log(#data, data)
    end)

    self:once('end', function(data)
        sb:append(data)

        local content = sb:toString()

        if (contentType == 'application/x-www-form-urlencoded') then
            self.body = querystring.parse(content)

        elseif (contentType == 'multipart/form-data') then
            local FormData = formdata.FormData
            local parser = FormData:new(#content)

            local body = {}
            local files = {}

            local headerName = nil
            local feilds = {}
            local fieldName = nil

            parser:on('file', function(data)
                -- console.log('file', data, headerName, feilds)

                if (feilds.filename) then
                    local file = { data = data }
                    file.name = feilds.name
                    file.filename = feilds.filename
                    file.mimetype = feilds.mimetype

                    files[#files + 1] = file

                else
                    body[feilds.name] = data
                end

                headerName = nil
                feilds = {}
            end)

            parser:on('header-name', function(data)
                -- console.log('header-name', data)
                headerName = data
                fieldName = nil
            end)

            parser:on('header-value', function(data)
                -- console.log('header-value', data)
                if (headerName == 'Content-Type') then
                    feilds['mimetype'] = data
                end
            end)

            parser:on('feild-name', function(data)
                -- console.log('feild-name', data)
                fieldName = data
            end)

            parser:on('feild-value', function(data)
                -- console.log('feild-value', fieldName, data)
                feilds[fieldName] = data
            end)

            parser:processData(content)
            parser = nil

            self.files = files
            self.body = body

        elseif (contentType == 'application/json') then
            self.body = json.parse(content)

        else
            self.body = content
        end

        if (not self.body) then
            self.body = ''
        end

        sb = nil
        contentType = nil
        callback(self)
    end)
end

-------------------------------------------------------------------------------
-- ServerResponse

function ServerResponse:checkSessionId()
    local sessionId = self.sessionId
    if (sessionId) then
        return
    end

    sessionId = tostring(math.floor(os.uptime() * 1000) + IncomingCounter)
    local cookie = "LSESSIONID=" .. sessionId .. ";path=/"
    self:set("Set-Cookie", cookie)

    IncomingCounter = (IncomingCounter + 1) % 1000
    --console.log('id', sessionId)
end

function ServerResponse:get(field)
    if (field) then
        return self:getHeader(field)
    end
end

function ServerResponse:json(data)
    local text = json.stringify(data)
    if (not text) then
        self:sendStatus(500)
        return
    end

    self:set("Content-Type", "application/json")
    self:set("Content-Length", #text)

    self:checkSessionId()
    self:write(text)
    self:finish()
end

function ServerResponse:redirect(status, path)
    if (type(status) == 'string') then
        path = status
        status = nil
    end

    self:set("Location", path)
    self:sendStatus(status or 300)
    self:finish()
end

function ServerResponse:send(text, contentType)
    if (not text) then
        self:sendStatus(500)
        return
    end

    self:set("Content-Type", contentType or "text/html")
    self:set("Content-Length", #text)

    self:checkSessionId()
    self:write(text)
    self:finish()
end

function ServerResponse:sendFileList(filename, request)
    local indexFile = path.join(filename, 'index.html')
    fs.stat(indexFile, function (err, statInfo)
        if (not statInfo) then
            local content = _getFileList(filename, request.uri.pathname)
            self:send(content)
            return
        end

        local contentType = mime["html"] or mime.default
        local options = {
            filename = indexFile,
            statInfo = statInfo,
            contentType = contentType,
            pathname = request.uri.pathname or '',
            ifSince =  request.headers['If-Modified-Since']
        }

        self:sendStaticFile(options)
    end)
end

function ServerResponse:sendStaticFile(options)
    local pathname = options.pathname

    if (not pathname:endsWith('.html')) then
        local since = options.ifSince
        local value = os.date("!%a, %d %b %Y %H:%M:%S GMT", options.statInfo.mtime.sec)

        if since and (since == value) then
            self:sendStatus(304)
            return
        end

        self:set('Last-Modified', value)
    end

    local fileStream = fs.createReadStream(options.filename)
    self:sendStream(fileStream, options.contentType, options.statInfo.size)
end


function ServerResponse:sendStatus(statusCode, message)
    self:status(statusCode)

    local STATUS_CODES = http.STATUS_CODES or {}
    if (statusCode < 400) then
        -- 不能有消息体
        self:checkSessionId()
        self:finish()
        return
    end

    local statusText = (STATUS_CODES[statusCode] or 'Status')
    local sb = StringBuffer:new()
    sb:append('<h1>'):append(statusCode):append(' '):append(statusText):append('</h1>')
    if (message) then
        sb:append('<hr/><p>'):append(message):append('</p>')
    end

    local data = sb:toString()
    self:set("Content-Type",   "text/html")
    self:set("Content-Length", #data)

    self:checkSessionId()
    self:write(data)
    self:finish()
end

function ServerResponse:sendStream(stream, contentType, contentLength)
    self:set("Content-Type",   contentType   or "text/html")
    self:set("Content-Length", tonumber(contentLength) or nil)

    self:checkSessionId()
    stream:pipe(self)
end

function ServerResponse:set(field, value)
    if (not field) then
        return
    end

    if (type(field) == 'table') then
        for k, v in pairs(field) do
            self:setHeader(k, v)
        end

    elseif (value) then
        self:setHeader(field, value)
    end
end

function ServerResponse:status(code)
    if (code and code > 0) then
        self.statusCode = code
    end

    return self.statusCode
end

function ServerResponse:type(contentType)
    if (contentType) then
        self:set('Content-Type', contentType)
    end

    return self:get('Content-Type')
end

-------------------------------------------------------------------------------
-- Express

local Express = core.Emitter:extend()
exports.Express = Express

function Express:initialize(options)
    if (not options) then
        options = {}
    end

    self.list 		= {}
    self.root 		= options.root
    self.routes     = {}
    self.functions  = {}
end

function Express:close()
    if (self.server) then
        self.server:close()
        self.server = nil
    end
end

function Express:use(func)
    table.insert(self.functions, func)
end

function Express:all(method, pathname, handler)
    if (not method) or (not pathname) or (not handler) then
        return
    end

    local route = self.routes[method]
    if (not route) then
        route = {}
        self.routes[method] = route
    end

    local tokens = pathname:split('/')
    --console.log(tokens)

    for index, item in ipairs(tokens) do
        --console.log(index, item)

        if (item and item ~= '') then
            local name = nil
            if (item:startsWith(':')) then
                name = item:sub(2)
                item = '@'
            end

            -- console.log(index, item)

            local subRoute = route[item]
            if (not subRoute) then
                subRoute = {}
                route[item] = subRoute
            end

            if (name) then
                subRoute['@name'] = name
            end

            route = subRoute
        end
    end

    route['@handler'] = handler
    -- console.log(self.routes)
end

function Express:get(pathname, handler)
    self:all('GET', pathname, handler)
end

function Express:getFileName(pathname)
    if (not self.root) then
        return nil
    end

    return path.join(self.root, pathname)
end

function Express:getHandler(request)
    local method = request.method
    local pathname = request.path or ''
    local handler = nil

    local route = self.routes[method] or {}

    local tokens = pathname:split('/')

    for index, item in ipairs(tokens) do
        if (item and item ~= '') then
            --console.log(index, item)

            local subRoute = route[item]
            if (not subRoute) then
                subRoute = route['@']
            end

            route = subRoute
            if (not route) then
                break
            end

            --console.log(route, value)
            local name = route['@name']
            if (name) then
                if (not request.params) then
                    request.params = {}
                end

                request.params[name] = item
            end
        end
    end


    if (route) then
        handler = route['@handler']
    end

    -- console.log(request.params, pathname, handler)
    return handler
end

function Express:post(pathname, handler)
    self:all('POST', pathname, handler)
end

function Express:handleFileRequest(request, response)
    local filename = self:getFileName(request.path)
    if (not filename) then
        return response:sendStatus(404)
    end

    fs.stat(filename, function (err, statInfo, ...)
        if err then
            if err.code == "ENOENT" then
                response:sendStatus(404, err.message)
                return

            elseif type(err) == 'string' and err:startsWith("ENOENT") then
                response:sendStatus(404, err.message)
                return
            end

            response:sendStatus(500, (err.message or tostring(err)))
            return
        end

        --console.log(stat.type)

        if (statInfo.type ~= 'file') then
            response:sendFileList(filename, request)
            return

        elseif (statInfo.type ~= 'file') then
            response:sendStatus(404, "Requested url is not a file")
            return
        end

        local extName = filename:lower():match("[^.]*$")
        local contentType = mime[extName] or mime.default
        local options = {
            filename = filename,
            statInfo = statInfo,
            contentType = contentType,
            pathname = request.uri.pathname or '',
            ifSince =  request.headers['If-Modified-Since']
        }

        response:sendStaticFile(options)
    end)
end

function Express:handleRequest(request, response)
    -- response.request = request
    local sessionId = request:getSessionId()
    response.sessionId = sessionId

    local uri           = url.parse(request.url)

    request.uri         = uri
    request.path        = uri.pathname
    request.hostname    = uri.hostname
    request.protocol    = uri.protocol or 'http'
    request.ip          = nil
    request.query       = querystring.parse(uri.query)

    -- 中间件
    for index, func in ipairs(self.functions) do
        local status, result = pcall(func, request, response)
        if (status and result) then
            return
        end
    end

    -- handler
    local handler = self:getHandler(request)
    if (not handler) then
        self:handleFileRequest(request, response)
        return
    end

    request:readBody(function()
        local status = pcall(handler, request, response)
        if (not status) then
            response:sendStatus(500)
        end
    end)
end

function Express:listen(port, callback)
    if (self.server) then
        return
    end

    local server = http.createServer(function(request, response)
        self:handleRequest(request, response)
    end)

    server:on('error', function(err, name)
        self:emit('error', err, name)
    end)

    server:on('close', function()
        self:emit('close')
    end)

    server:on('listening', function()
        self:emit('listening')

        if (self.root) then print("root: " .. self.root) end
        print("HTTP server listening at http://localhost:" .. port)
    end)

    self.server = server
    server:listen(port)

    if (callback) then
        callback(self)
    end
end

-------------------------------------------------------------------------------
-- exports

function exports.app(options)
    return Express:new(options)
end

setmetatable( exports, {
    __call = function(self, options)
        return Express:new(options)
    end
})

return exports
