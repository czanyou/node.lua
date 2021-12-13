local server = require('ssdp/server')
local client = require('ssdp/client')

local exports = {}

exports.version = server.version

function exports.server(options)
    return server(options)
end

function exports.client(options, callback)
    return client(options, callback)
end

-- Scanning for nearby devices
function exports.scan(timeout, serviceType)
	local err, ssdp = pcall(require, 'ssdp')
	if (not ssdp) then
		return
	end

	local list = {}
	print("Start scaning...")

	local ssdpClient = ssdp.client({}, function(response, rinfo)
		if (list[rinfo.ip]) then
			return
		end

		local headers   = response.headers
		local item      = {}
		item.remote     = rinfo
		item.usn        = headers["usn"] or ''

		list[rinfo.ip] = item

		--console.log(headers)

		local model = headers['X-DeviceModel']
		local name = rinfo.ip .. ' ' .. item.usn
		if (model) then
			name = name .. ' ' .. model
		end

		console.write('\r')  -- clear current line
		print(rinfo.ip, item.usn, model)
	end)

	-- search for a service type
	-- urn:schemas-webofthings-org:device
	serviceType = serviceType or 'urn:schemas-webofthings-org:device'
	ssdpClient:search(serviceType)

	local scanCount = 0
	local scanTimer = nil
	local scanMaxCount = tonumber(timeout) or 10

	scanTimer = setInterval(500, function()
		ssdpClient:search(serviceType)
		console.write("\r " .. string.rep('.', scanCount))

		scanCount = scanCount + 1
		if (scanCount >= scanMaxCount) then
			clearInterval(scanTimer)
			scanTimer = nil

			ssdpClient:stop()

			console.write('\r') -- clear current line
			print("End scaning...")
		end
	end)
end

return exports