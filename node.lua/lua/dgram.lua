--[[

Copyright 2014-2015 The Luvit Authors. All Rights Reserved.
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
meta.name        = "lnode/dgram"
meta.version     = "1.1.0-3"
meta.license     = "Apache 2"
meta.description = "Node-style udp module for lnode"
meta.tags        = { "lnode", "dgram", "udp" }

local exports = { meta = meta }

local core    = require('core')
local timer   = require('timer')
local uv      = require('uv')

-------------------------------------------------------------------------------
-- Socket

local Socket = core.Emitter:extend()
exports.Socket = Socket

function Socket:initialize(type, callback)
    self._handle = uv.new_udp()
    if callback then
        self:on('message', callback)
    end
end

function Socket:address()
    return uv.udp_getsockname(self._handle)
end

function Socket:bind(port, address, callback)
    local ret, err = uv.udp_bind(self._handle, address, port)
    if (err) then
        self:emit('error', err)
        return nil, err
    end

    self:recvStart()

    if (callback) then
        callback()
    end

    self:emit('listening')
    return ret
end

function Socket:close(callback)
    timer.unenroll(self)
    if not self._handle then
        return
    end

    self:recvStop()
    uv.close(self._handle, callback)
    self._handle = nil
end

function Socket:recvStart()
    uv.udp_recv_start(self._handle, function(err, msg, rinfo, flags)
        timer.active(self)
        if err then
            self:emit('error', err)

        elseif msg then
            self:emit('message', msg, rinfo, flags)
        end
    end )
end

function Socket:recvStop()
    return uv.udp_recv_stop(self._handle)
end

function Socket:send(data, port, host, callback)
    timer.active(self)
    return uv.udp_send(self._handle, data, host, port, callback)
end

function Socket:setBroadcast(status)
    return uv.udp_set_broadcast(self._handle, status)
end

function Socket:setMulticastInterface(interfaceAddress)
    return uv.udp_set_multicast_interface(self._handle, interfaceAddress)
end

function Socket:setMulticastLoop(on)
    return uv.udp_set_multicast_loop(self._handle, on)
end

function Socket:setMulticastTTL(ttl)
    return uv.udp_set_multicast_ttl(self._handle, ttl)
end

function Socket:setTimeout(msecs, callback)
    if msecs > 0 then
        timer.enroll(self, msecs)
        timer.active(self)
        if callback then
            self:once('timeout', callback)
        end
        
    elseif msecs == 0 then
        timer.unenroll(self)
    end
end

function Socket:setTTL(ttl)
    uv.udp_set_ttl(self._handle, ttl)
end

-- ==
-- Membership

function Socket:addMembership(multicastAddress, interfaceAddress)
    return self:setMembership(multicastAddress, interfaceAddress, 'join')
end

function Socket:dropMembership(multicastAddress, interfaceAddress)
    return self:setMembership(multicastAddress, interfaceAddress, 'leave')
end

function Socket:setMembership(multicastAddress, multicastInterface, op)
    if not multicastAddress then
        error("multicast address must be specified")
    end

    if not multicastInterface then
        if self._family == 'udp4' then
            multicastInterface = '0.0.0.0'
        elseif self._family == 'udp6' then
            multicastInterface = '::0'
        end
    end

    local ret, err = uv.udp_set_membership(self._handle, multicastAddress, multicastInterface, op)
    if (err) then
        self:emit('error', err)
    end
    return ret
end

-------------------------------------------------------------------------------

function exports.createSocket(type, callback)
    local ret = Socket:new(type, callback)
    ret._family = type
    return ret
end

return exports;

