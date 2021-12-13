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

local ssdp = require('ssdp/ssdp')

local exports = {}

local INET_ADDR_ANY  = ssdp.INET_ADDR_ANY

-------------------------------------------------------------------------------
--

local function createMSearchMessage(serviceType)
	local sb = StringBuffer:new()
	sb:append("M-SEARCH * HTTP/1.1\r\n")
	sb:append("Host:239.255.255.250:1900\r\n")
	sb:append("ST:"):append(serviceType):append("\r\n")
	sb:append('Man:"ssdp:discover"\r\n')
	sb:append("MX:3\r\n")
	sb:append("\r\n")
	return sb:toString()
end

-------------------------------------------------------------------------------
--- SsdpClient

local SsdpClient = ssdp.SsdpObject:extend()
exports.SsdpClient = SsdpClient

function SsdpClient:initialize(options, socket)
	options = options or {}

	self.socket 	= socket
	self.port       = options.ssdpPort  or ssdp.UPNP_PORT
	self.ssdpIp     = options.ssdpIp   	or ssdp.UPNP_ADDRESS
	self._started	= false
end

function SsdpClient:_handleNotify(request, remote)
	self:emit('request', request, remote)
end

function SsdpClient:_handleResponse(response, remote)
	-- console.log(response.code, remote.ip, remote.port)
	self:emit('response', response, remote)
end

function SsdpClient:search(serviceType)
	if (not self._started) then
		self:start()
	end

	serviceType  = serviceType or 'ssdp:all'
	local request = createMSearchMessage(serviceType)
	self:_sendMessage(request)

	local addresses = self:_getLocalAddresses()
	for _, address in pairs(addresses) do
		-- print(request, address.broadcast, self.port)
		self:_sendMessage(request, address.broadcast, self.port)
	end
end

function SsdpClient:start(localAddress, localPort)
	if (not self._started) then
		self:_createSocket((localAddress or INET_ADDR_ANY), (localPort or 0))
		self._started = true
	end
end

function SsdpClient:stop()
	self:_stop()

	self._started = false
end

-------------------------------------------------------------------------------
--

function exports.open(options, callback)
	options = options or {}

	local port 		  = options.port or 1902
	local localAddrss = options.localAddrss or '0.0.0.0'
	local localPort   = options.localPort or 0
	local client 	  = SsdpClient:new(options)

	if (callback) then
		client:on('response', callback)
	end

	return client
end

setmetatable(exports, {
	__call = function(self, options, callback)
		return self.open(options, callback)
	end
})

return exports

