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

local meta = {}
meta.name        = "lnode/https"
meta.version     = "1.0.1"
meta.license     = "Apache 2"
meta.description = "Node-style https client and server module for lnode"
meta.tags        = {"lnode", "https", "stream"}

local exports = { meta = meta }

local tls  = require('tls')
local http = require('http')

-- [port] [host] [options]
local function _createConnection(...)
    local args = {...}
    local options = {}
    local callback

    if type(args[1]) == 'table' then
        options = args[1]

    elseif type(args[2]) == 'table' then
        options = args[2]
        options.port = args[1]

    elseif type(args[3]) == 'table' then
        options = args[3]
        options.port = args[2]
        options.host = args[1]

    else
      if type(args[1]) == 'number' then
          options.port = args[1]
      end

      if type(args[2]) == 'string' then
          options.host = args[2]
      end
    end

    if type(args[#args]) == 'function' then
        callback = args[#args]
    end

    return tls.connect(options, callback)
end

function exports.createServer(options, onRequest)
    return tls.createServer(options, function (socket)
        return http.handleConnection(socket, onRequest)
    end)
end

function exports.get(options, onResponse)
    options = http.parseUrl(options)
    options.method = 'GET'

    local request = exports.request(options, onResponse)
    request:done()  
    return request
end

function exports.request(options, callback)
    options = http.parseUrl(options)
    if options.protocol and (options.protocol ~= 'https') then
        error(string.format('Protocol %s not supported', options.protocol))
    end

    options.connect_emitter = 'secureConnection'
    options.port    = options.port or 443
    options.socket  = options.socket or _createConnection(options)
    return http.request(options, callback)
end

return exports
