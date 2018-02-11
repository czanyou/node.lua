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
local utils = require('utils')
local http 	= require('http')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local timer = require('timer')
local json  = require('json')
local mime 	= require('express/mime')

local querystring  = require('querystring')

local ServerResponse  = http.ServerResponse
local IncomingMessage = http.IncomingMessage

local exports = { }
local IncomingCounter = 0

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

local httpSessions = {}

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
    local sessionId = self:getSessionId()
    local httpSession = sessionId and httpSessions[sessionId]
    if (not httpSession) and create then
        httpSession = {}
        httpSessions[sessionId] = httpSession
    end

    -- console.log(sessionId, httpSessions)
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
    local sb = StringBuffer:new()

    self:on('data', function(data)
        sb:append(data)
    end)

    self:on('end', function(data)
        sb:append(data)

        local content = sb:toString()
        if (contentType == 'application/x-www-form-urlencoded') then
            self.body = querystring.parse(content)

        elseif (contentType == 'multipart/form-data') then
            self.body = querystring.parse(content)

        elseif (contentType == 'application/json') then
            self.body = json.parse(content)  

        else 
            self.body = content
        end

        if (not self.body) then
            self.body = ''
        end

        callback(self)
    end)
end

-------------------------------------------------------------------------------
-- ServerResponse

function ServerResponse:checkSessionId()
    local sessionId = self.request:getSessionId()
    if (not sessionId) then
        sessionId = tostring(math.floor(os.uptime() * 1000) + IncomingCounter)
        cookie = "LSESSIONID=" .. sessionId .. ";path=/"
        self:set("Set-Cookie", cookie)

        IncomingCounter = (IncomingCounter + 1) % 1000
    end

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
        self:sendStatus(400)
        return
    end

    self:set("Content-Type", "application/json")
    self:set("Content-Length", #text)

    self:checkSessionId()
    self:write(text)
end

function ServerResponse:redirect(status, path)
    if (type(status) == 'string') then
        path = status
        status = nil
    end

    self:set("Location", path)
    self:sendStatus(status or 300)
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
end

function ServerResponse:sendFile(filename)
    fs.stat(filename, function (err, statInfo)
        if err then
            if err.code == "ENOENT" then
                self:sendStatus(404, err.message)
                return
            end

            self:sendStatus(500, (err.message or tostring(err)))
            return
        end

        --console.log(stat.type)

        if (statInfo.type ~= 'file') then
            self:sendFileList(filename)
            return

        elseif (statInfo.type ~= 'file') then
            self:sendStatus(404, "Requested url is not a file")
            return
        end

        local extName = filename:lower():match("[^.]*$")
        if (extName == 'lua') then
            self:sendScriptFile(filename)

        else
            local contentType = mime[extName] or mime.default
            self:sendStaticFile(filename, statInfo, contentType)
        end
    end)
end

function ServerResponse:sendFileList(filename)
    local indexFile = path.join(filename, 'index.html')
    fs.stat(indexFile, function (err, statInfo)
        if (not statInfo) then
            local content = _getFileList(filename, self.request.uri.pathname)
            self:send(content)
            return
        end

        local contentType = mime["html"] or mime.default
        self:sendStaticFile(indexFile, statInfo, contentType)
    end)
end

function ServerResponse:sendScript(filedata, filename)
    local env = {}
    for k, v in pairs(_G) do
        env[k] = v
    end

    local script, err

    local handler = function(message)
        err = (message or '') .. "\r\n" .. debug.traceback()
    end

    env.request  = self.request
    env.response = self
    script, err = load(filedata, filename or '__', "t", env)
    local content = ""
    if (script) then
        content = xpcall(script, handler)
        if (content == true) then
            return
        end
    end

    if (err) then
        content = '<pre><code>' .. tostring(err) .. '</code></pre>'
        self:sendStatus(500, content)
        return
    end

    if (type(content) ~= 'string') or (#content < 1) then
        content = "internal error!"
        self:sendStatus(500, content)
        return
    end

    self:send(content)
end

function ServerResponse:sendScriptFile(filename)
    fs.readFile(filename, function(err, filedata)
        if (not filedata) then
            self:sendStatus(404, "Requested url is not a file")
            return
        end

        self:sendScript(filedata, filename)
    end)
end

function ServerResponse:sendStaticFile(filename, statInfo, contentType)
    local pathname = self.request.uri.pathname or ''

    if (not pathname:endsWith('.html')) then
        local since = self.request.headers['If-Modified-Since']
        local value = os.date("!%a, %d %b %Y %H:%M:%S GMT", statInfo.mtime.sec)

        if since and (since == value) then
            self:sendStatus(304)
            return
        end

        self:set('Last-Modified', value)
    end

    local fileStream = fs.createReadStream(filename)
    self:sendStream(fileStream, contentType, statInfo.size)
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
end

function ServerResponse:sendStream(stream, contentType, contentLength)
    self:set("Content-Type",   contentType   or "text/html")
    self:set("Content-Length", contentLength or nil)

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

    self.list 		   = {}
    self.root 		   = options.root
	self._getMethods   = {}
	self._postMethods  = {}
end

function Express:close()
    if (self.server) then
        self.server:close()
        self.server = nil
    end
end

function Express:get(pathname, handler)
	self._getMethods[pathname] = handler
end

function Express:getFileName(pathname)
    if (not self.root) then
        return nil
    end

    return path.join(self.root, pathname)
end

function Express:getHandler(request)
    local method = request.method
    local pathname = request.path
    local handler = nil
    if (method == 'POST') then
        handler = self._postMethods[pathname]

    else
		handler = self._getMethods[pathname]
    end

    return handler
end

function Express:post(pathname, handler)
	self._postMethods[pathname] = handler
end

function Express:onRequest(request, response)
    -- 子类可以实现这个方法来处理请求
    return false
end

function Express:handleRequest(request, response)
    response.request = request

	local uri           = url.parse(request.url)

    request.uri         = uri
    request.path        = uri.pathname
    request.hostname    = uri.hostname
    request.protocol    = uri.protocol or 'http'
    request.ip          = nil
    request.query       = querystring.parse(uri.query)

    -- 供子类拦截所有请求处理
    if (self:onRequest(request, response)) then
        return
    end

    -- handler
    local handler = self:getHandler(request)
    if (handler) then
        --self:handleWithHandler(request, response, handler)
        request:readBody(function()
            handler(request, response)
        end)
        return
    end

    -- file
	local filename = self:getFileName(request.path)
    if (filename) then
        response:sendFile(filename)
    else
        response:sendStatus(404)
    end
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
