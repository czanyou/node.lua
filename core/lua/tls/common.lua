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
local Object = require('core').Object
local Error = require('core').Error
local net = require('net')
local timer = require('timer')
local utils = require('util')
local uv = require('luv')
local tls = require('lmbedtls.tls')

local exports = {}

local DEFAULT_CIPHERS = 'ECDHE-RSA-AES128-SHA256:AES128-GCM-SHA256:' .. -- TLS 1.2
    'RC4:HIGH:!MD5:!aNULL:!EDH' -- TLS 1.0
exports.DEFAULT_CIPHERS = DEFAULT_CIPHERS

-------------------------------------------------------------------------------
-- Credential

---@class Credential
local Credential = Object:extend()

function Credential:initialize(secureProtocol, defaultCiphers, flags, rejectUnauthorized, context)
    self.rejectUnauthorized = rejectUnauthorized
    if context then
        self.context = context

    else
        --self.context = openssl.ssl.ctx_new(secureProtocol or 'TLSv1',
        --  defaultCiphers or DEFAULT_CIPHERS)
        --self.context:mode(true, 'release_buffers')
        --self.context:options(getSecureOptions(secureProtocol, flags))
        end
end

function Credential:addRootCerts()
--self.context:cert_store(exports.DEFAULT_CA_STORE)
end

function Credential:setCA(certs)
    if not self.store then
        --self.store = openssl.x509.store:new()
        --self.context:cert_store(self.store)
        end

    if type(certs) == 'table' then
        for _, v in pairs(certs) do
            --local cert = assert(openssl.x509.read(v))
            --assert(self.store:add(cert))
            end
    else
        --local cert = assert(openssl.x509.read(certs))
        --assert(self.store:add(cert))
        end
end

function Credential:setKeyCert(key, cert)
    --key = assert(openssl.pkey.read(key, true))
    --cert = assert(openssl.x509.read(cert))
    self.context:use(key, cert)
end

exports.Credential = Credential

-------------------------------------------------------------------------------
-- TLSSocket
-- @event secureConnect
-- @event OCSPResponse
local TLSSocket = net.Socket:extend()

function TLSSocket:initialize(socket, options)
    local socketOptions
    if socket then
        -- server socket
        socketOptions = {handle = socket._handle}
    end

    net.Socket.initialize(self, socketOptions)

    -- options
    self.options = options
    self.ctx = options.secureContext
    self.server = options.isServer
    self.requestCert = options.requestCert
    self.rejectUnauthorized = options.rejectUnauthorized

    if self._handle == nil then
        -- client socket
        self:once('connect', function() self:onConnect() end)
    else
        -- server socket
        self:onConnect()
    end

    -- state
    self._connected = false
    self.encrypted = true
    self.readable = true
    self.writable = true
    self.readBuffer = ''

    if self.server then
        self._connecting = false
        self:once('secure', utils.bind(self._verifyServer, self))

    else
        self._connecting = true
        self:once('secure', utils.bind(self._verifyClient, self))
    end

    if socket then
        self._connecting = socket._connecting
    end

    self:once('close', function()
        -- console.log('tls.close')
    end)

    self:once('end', function()
        -- console.log('tls.end')
        self:destroy()
    end)
end

function TLSSocket:onConnect()
    -- console.log('tls.connect');

    local MBEDTLS_ERR_SSL_WANT_READ = -0x6900 -- 26800 /**< Connection requires a read call. */

    local function onWrite(err)

    end

    -- write to low layer raw socket
    local function _tlsWrite(data)
        --net.Socket._write(self, data, onWrite)
        -- console.log('write', ret, #data)

        local ret = net.Socket.write(self, data, onWrite)
        self._needDrain = ret
        return #data
    end

    -- read from low layer raw socket
    local function _tlsRead(len)
        -- console.log('read', len)
        local readBuffer = self.readBuffer

        if (#readBuffer >= len) then
            local data = readBuffer:sub(1, len)
            self.readBuffer = readBuffer:sub(len + 1)

            return #data, data
        end

        return MBEDTLS_ERR_SSL_WANT_READ
    end

    local function _tlsCallback(data, len)
        if (len) then
            return _tlsRead(len)

        else
            return _tlsWrite(data)
        end
    end

    local options = self.options
    local hostname = options.host or options.servername
    -- console.log('hostname', hostname)

    self.ssl = tls.new()
    self.ssl:config(hostname, 0, _tlsCallback)

    self:read(0)
    self.ssl:handshake()
end

-- Returns an object representing the peer's certificate.
function TLSSocket:getPeerCertificate()

end

function TLSSocket:_verifyClient()
    console.log('_verifyClient')

    if self.ssl:session_reused() then
        self.sessionReused = true
        self:emit('secureConnect', self)

    else
        local verifyError, verifyResults
        self.ctx.session = self.ssl:session()
        verifyError, verifyResults = self.ssl:getpeerverification()
        if verifyError then
            self.authorized = true
            self:emit('secureConnect', self)
        else
            self.authorized = false
            self.authorizationError = verifyResults[1].error_string
            if self.rejectUnauthorized then
                local err = Error:new(self.authorizationError)
                self:destroy(err)
            else
                self:emit('secureConnect', self)
            end
        end
    end
end

function TLSSocket:_verifyServer()
    console.log('_verifyServer')

    if self.requestCert then
        local peer, verify, err
        peer = self.ssl:peer()
        if peer then
            verify, err = self.ssl:getpeerverification()
            self.authorizationError = err
            if verify then
                self.authorized = true
            elseif self.rejectUnauthorized then
                self:destroy(err)
            end
        elseif self.rejectUnauthorized then
            self:destroy(Error:new('reject unauthorized'))
        end
    end

    if not self.destroyed then
        self:emit('secureConnect', self)
    end
end

function TLSSocket:destroy(err)

    local hasShutdown = false
    local reallyShutdown = function()
        if hasShutdown then return end
        hasShutdown = true
        net.Socket.destroy(self, err)
    end

    local shutdown = nil

    shutdown = function()
        timer.active(self)
        if self._shutdown then
            local _, shutdown_err = self.ssl:shutdown()
            if shutdown_err == "want_read" or shutdown_err == "want_write" or shutdown_err == "syscall" then
                local r = self.out:pending()
                if r > 0 then
                    timer.active(self._shutdownTimer)
                    net.Socket._write(self, self.out:read(), function(err)
                        timer.active(self._shutdownTimer)
                        if err then
                            self._shutdown = false
                            return reallyShutdown()
                        end
                        shutdown()
                    end)
                end
            else
                self._shutdown = false
                return reallyShutdown()
            end
        end
    end

    local onShutdown = function(read_err, data)
        timer.active(self)
        if read_err or not data then
            return reallyShutdown()
        end
        timer.active(self._shutdownTimer)
        self.inp:write(data)
        shutdown()
    end

    if self.destroyed or self._shutdown then return end
    if self.ssl and self.authorized then
        if not self._shutdownTimer then
            self._shutdownTimer = timer.setTimeout(5000, reallyShutdown)
        end
        self._shutdown = true
        uv.read_stop(self._handle)
        uv.read_start(self._handle, onShutdown)
        self:emit('shutdown')
        shutdown()
    else
        reallyShutdown()
    end
end

function TLSSocket:connect(...)
    local args = {...}
    local secureCallback

    if type(args[#args]) == 'function' then
        secureCallback = args[#args]
        args[#args] = nil
    end

    self:on('secureConnect', secureCallback)
    net.Socket.connect(self, table.unpack(args))
end

function TLSSocket:write(chunk, callback)
    if type(callback) ~= 'function' then
        callback = function() end
    end

    if self.writableEnded then
        local err = Error:new('write after end')
        self:emit('error', err)
        setImmediate(function() callback(err) end)

    elseif (chunk ~= nil) and (type(chunk) ~= 'string') then
        local err = Error:new('Invalid non-string chunk')
        self:emit('error', err)
        setImmediate(function() callback(err) end)
    end

    local ret = self.ssl:write(chunk)
    if (callback) then callback() end

    return self._needDrain
end

function TLSSocket:_read(n)
    -- console.log('_read', n)

    local function onRawData(err, data)
        timer.active(self)

        if err then
            return self:destroy(err)

        elseif (not data) then
            self:push(nil)
            self:emit('_socketEnd')
            return
        end

        --console.log('data', #data)
        self.readBuffer = self.readBuffer .. data

        if (self.isHandshake) then
            while (true) do
                local size, raw = self.ssl:read();
                if (size <= 0) then
                    break
                end

                -- console.log('tls.data', size, #raw, raw)
                self:push(raw)
            end

        else
            -- handshake
            local ret = self.ssl:handshake()
            if (ret == 0) then
                -- console.log('handshake is done')
                self:emit('secureConnect', self)
                self.isHandshake = true
            end
        end
    end

    if not self._reading then
        self._reading = true
        uv.read_start(self._handle, onRawData)
    end
end

exports.TLSSocket = TLSSocket

-------------------------------------------------------------------------------

function exports.createCredentials(options, context)
    local VERIFY_PEER = {"peer"}
    local VERIFY_PEER_FAIL = {"peer", "fail_if_no_peer_cert"}
    local VERIFY_NONE = {"none"}

    local ctx, returnOne

    options = options or {}

    ctx = Credential:new(options.secureProtocol, options.ciphers,
        options.secureOptions, options.rejectUnauthorized, context)
    if context then
        return ctx
    end

    if options.key and options.cert then
        ctx:setKeyCert(options.key, options.cert)
    end

    if options.ca then
        ctx:setCA(options.ca)
    else
        ctx:addRootCerts()
    end

    local returnOne = function()
        return 1
    end

    if options.server then
        if options.requestCert then
            if options.rejectUnauthorized then
                ctx.context:verify_mode(VERIFY_PEER_FAIL, returnOne)
            else
                ctx.context:verify_mode(VERIFY_PEER, returnOne)
            end
        else
            ctx.context:verify_mode(VERIFY_NONE, returnOne)
        end
    else
        --ctx.context:verify_mode(VERIFY_NONE, returnOne)
        end

    return ctx
end

return exports
