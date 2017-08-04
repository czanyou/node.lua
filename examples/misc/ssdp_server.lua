local pprint = console.pprint
local server = require('ssdp/server')

local ssdp = nil

-- 模拟一个可被发现的 SSDP 服务端。

local SSDP_PORT = 1902
local SSDP_HOST = "0.0.0.0"

function main()
	local server = require('ssdp/server')
	local SsdpServer = server.SsdpServer
	ssdp = SsdpServer:new({ port = SSDP_PORT, interval = 1000 })
	ssdp:start(SSDP_HOST)

	print('SSDP server started.')
end

main()
