--[[

Copyright 2014-2015 The Luvit Authors. All Rights Reserved.
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
    description = "A node-style tls module for lnode."
}

local exports = { meta = meta }

local common = require('tls/common')
local net = require('net')

local extend = function(...)
    local args = {...}
    local obj = args[1]
    for i=2, #args do
        for k,v in pairs(args[i]) do
            obj[k] = v
        end
    end
    return obj
end

local Server = net.Server:extend()

function Server:init(options, connectionListener)
    options = options or {}
    options.server = true

    local sharedCreds = common.createCredentials(options)
    net.Server.init(self, options, function(raw_socket)
        local socket
        socket = common.TLSSocket:new(raw_socket, {
            secureContext   = sharedCreds,
            isServer        = true,
            requestCert     = options.requestCert,
            rejectUnauthorized = options.rejectUnauthorized,
        })

        socket:on('secureConnect', function()
            connectionListener(socket)
        end)

        socket:on('error', function(err)
            connectionListener(socket, err)
        end)

        self.socket = socket
        if self.sni_hosts then
            socket:sni(self.sni_hosts)
        end
    end)
end

function Server:sni(hosts)
    self.sni_hosts = hosts
end

local DEFAULT_OPTIONS = {
    ciphers = common.DEFAULT_CIPHERS,
    rejectUnauthorized = true
}

function exports.connect(options, callback)
    local hostname, port, socket

    callback = callback or function() end
    options = extend({}, DEFAULT_OPTIONS, options or {})
    port = options.port
    hostname = options.host or options.servername

    -- console.log('options', hostname, port, options);

    socket = common.TLSSocket:new(nil, options)
    socket:connect(port, hostname, callback)
    return socket
end

function exports.createServer(options, secureCallback)
    local server = Server:new()
    server:init(options, secureCallback)
    return server
end

exports.TLSSocket = common.TLSSocket

exports.createCredentials = common.createCredentials

return exports
