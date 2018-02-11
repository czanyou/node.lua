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
local json   = require('json')
local path 	 = require('path')
local ssdp   = require('ssdp/ssdp')
local utils  = require('utils')

local exports = {}

local TAG = 'SsdpServer'

local UPNP_ADDRESS 		= ssdp.UPNP_ADDRESS
local UPNP_PORT 		= ssdp.UPNP_PORT
local UPNP_ROOT_DEVICE	= ssdp.UPNP_ROOT_DEVICE
local INET_ADDR_ANY  	= ssdp.INET_ADDR_ANY

exports.version = "2.0"

-------------------------------------------------------------------------------
--- SsdpServer

local SsdpServer = ssdp.SsdpObject:extend()
exports.SsdpServer = SsdpServer

function SsdpServer:initialize(options, socket)
	options = options or {}

	self.deviceId		= options.udn
	self.ssdpIp         = options.ssdpIp   	or UPNP_ADDRESS	
	self.adInterval     = options.adInterval or 1000 * 10
	self.location		= options.location
	self.deviceModel	= options.deviceModel
	self.port           = options.ssdpPort 	or UPNP_PORT
	self.ssdpSig 		= options.ssdpSig  	or "Node.lua/2.2, UPnP/1.0, ssdp/2.0"
	self.ssdpTtl		= options.ssdpTtl 	or 1
	self.ttl			= options.ttl 		or 1800
	self.unicastHost	= options.unicastHost or INET_ADDR_ANY
	self.description	= options.description or "/device.json"

	self.intervalTimer 	= nil
	self.socket 		= socket
	self.usns			= {}
end

function SsdpServer:_encodeNotify(nt, nts, usn)
	local sb = StringBuffer:new()
	sb:append("NOTIFY * HTTP/1.1\r\n")
	sb:append("Host:239.255.255.250:1900\r\n")
	sb:append("Cache-Control:max-age=1800\r\n")
	sb:append("Location:"):append(self:_getLocation()):append("\r\n")
	sb:append("NT:"):append(nt):append("\r\n")
	sb:append("NTS:"):append(nts):append("\r\n")
	sb:append("Server:"):append(self.ssdpSig):append("\r\n")
	sb:append("USN:"):append(usn):append("\r\n")

	if (self.deviceModel) then
		sb:append("X-DeviceModel:"):append(self.deviceModel):append("\r\n")
	end

	sb:append("\r\n")
	return sb:toString()
end

function SsdpServer:_encodeResponse(serviceType, usn)
	local sb = StringBuffer:new()
	sb:append("HTTP/1.1 200 OK\r\n")
	sb:append("Cache-Control:max-age=1800\r\n")
	sb:append("Date:"):append(exports.newDateHeader()):append("\r\n")
	sb:append("Location:"):append(self:_getLocation()):append("\r\n")
	sb:append("Server:"):append(self.ssdpSig):append("\r\n")
	sb:append("ST:"):append(serviceType):append("\r\n")
	sb:append("USN:"):append(usn):append("\r\n")

	if (self.deviceModel) then
		sb:append("X-DeviceModel:"):append(self.deviceModel):append("\r\n")
	end

	sb:append("\r\n")
	return sb:toString()
end

function SsdpServer:_getLocation()
	if (self.location) then 
		if (type(self.location) == 'function') then
			return self.location()
		else
			return self.location
		end
	end

	local localAddress = self:getLocalAddress()
	return "http://" .. localAddress .. self.description
end

function SsdpServer:_handleSearch(request, remote)
	local st  = request.headers['st'] or UPNP_ROOT_DEVICE
	--print('st', st)
	if (st ~= 'urn:schemas-upnp-org:service:cmpp-iot') then
		return
	end

	local usn = self.deviceId or 'uuid:123456'
	local response = self:_encodeResponse(st, usn)
	--console.log('handleSearch', remote.port, remote.ip, response)

	self:_sendMessage(response, remote.ip, remote.port)
	self:_sendMessage(response, UPNP_ADDRESS, remote.port)
end

function SsdpServer:_startNotifyLoop()
	if (self.intervalTimer) then
		return
	end

	self.intervalTimer = setInterval(self.adInterval, function()
		self:notify(true)
	end)
end

function SsdpServer:_stopNotifyLoop()
	if (self.intervalTimer) then
		clearInterval(self.intervalTimer)
		self.intervalTimer = nil
	end
end

function SsdpServer:addUSN(usn)
	if (usn) then
		self.usns[usn] = usn
	end
end

function SsdpServer:getLocalAddress()
	local addresses = self:_getLocalAddresses()
	for _, address in pairs(addresses) do
		return address.ip
	end

	return '0.0.0.0'
end

function SsdpServer:notify(alive)
	local nt  = UPNP_ROOT_DEVICE
	local nts = "ssdp:alive"
	local usn = self.deviceId or 'uuid:123456'

	if (not alive) then
		nts = "ssdp:byebye"
	end

	local message = self:_encodeNotify(nt, nts, usn)
	self:_sendMessage(message, function() end)
end

function SsdpServer:start(localAddress)
	if (not self._started) then
		self:_createSocket(localAddress or INET_ADDR_ANY)
		self._started = true

		self:_startNotifyLoop()

		self:notify(true)
	end
end

function SsdpServer:stop()
	self:_stopNotifyLoop()
end

-------------------------------------------------------------------------------

function exports.newDateHeader()
    return os.date("%a, %d %b %Y %H:%M:%S GMT", os.time())
end

-------------------------------------------------------------------------------
-- 

function exports.open(options, callback)
	local ssdpServer = SsdpServer:new(options)

	ssdpServer:start()

	return ssdpServer
end

setmetatable(exports, {
	__call = function(self, options, callback)
		return self.open(options, callback)
	end
})

return exports

