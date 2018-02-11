local dgram  = require('dgram')
local pprint = console.pprint
local server = require('ssdp/server')

local request = 'M-SEARCH * HTTP/1.1\r\nHost:239.255.255.250:1900\r\nCache-Control:max-age=120\r\nLocation:http://192.168.77.101/desc.xml\r\nNT:upnp:rootdevice\r\nNTS:ssdp:alive\r\nServer:Linux/3.0, UPnP/1.0, Node.lua\r\nX-User-Agent:Vision\r\nUSN:uuid:upnp-Vision-123456\r\n\r\n'

function test_ssdp_server()
	local UPNP_ROOT_DEVICE	= "upnp:rootdevice"

	local localHost = "192.168.77.101"
	local nt  = UPNP_ROOT_DEVICE
	local nts = "ssdp:alive"
	local usn = "uuid:upnp-Vision-123456"

	local SsdpServer = server.SsdpServer
	local ssdp = SsdpServer:new()
	local message = ssdp:_encodeNotify(localHost, nt, nts, usn)
	print(message)

	local message = ssdp:_encodeResponse(localHost, usn)
	print(message)	

	local event = ssdp:_parseMessage(request)
	pprint(event)
end

test_ssdp_server()

run_loop()


