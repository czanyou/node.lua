local pprint = console.pprint
local client = require('ssdp/client')

-- 搜索局域网内的 SSDP 设备。

local SSDP_PORT = 1902
local SSDP_HOST = "0.0.0.0"

function main()
	local list = {}

	local SsdpClient = client.SsdpClient
	ssdp = SsdpClient:new({ port = SSDP_PORT })
	ssdp:start(SSDP_HOST, SSDP_PORT)

	ssdp:on('response', function(response, remote)
		if (list[remote.ip]) then
			return
		end

		local headers = response.headers or {}

		local item = {}
		item.remote 	= remote
		item.usn 		= headers["usn"]
		item.st 		= headers["st"]
		item.location 	= headers["location"]

		list[remote.ip] = item
		pprint(item)
	end)

	local timer = setInterval(1000, function()
		print('SSDP searching...')

		ssdp:search('ssdp:all')
	end)

	setTimeout(5000, function()
		clearInterval(timer)
		ssdp:stop()

		print('SSDP search timeout!')
	end)
end

main()
