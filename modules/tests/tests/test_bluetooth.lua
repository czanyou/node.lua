local ble 		= require('lbluetooth')
local fs  		= require('fs')
local thread 	= require('thread')
local utils  	= require('utils')
local app  		= require('app')

-- 访问蓝牙设备必须有管理员权限

local function main()
	ble.reset()
	--console.log(ble)

	local flags = ble.FLAG_SCAN_ACTIVE
	--print('flags', flags)
	local lbluetooth = ble.open(flags)
	if (not lbluetooth) then
		return
	end

	console.log(lbluetooth)

	local beacons = {}

	local function stat(beacon)
		local list = beacon.rssi
		local map = {}
		for i = 1, #list do
			local rssi = tonumber(list[i] or 0)
			map[rssi] = (map[rssi] or 0) + 1
		end

		console.log(beacon.mac)

		local table = app.table({12, 12, 12})
		table.line()
		table.cell("Signal", "Count", "Percent")
		table.line()

		for i = 1, 256 do
			local value = map[i]
			if (value) then
				--print((i - 256) .. "dB: ", value)

				table.cell(i - 256, value, math.floor(value * 100 / #list) .. "%")
			end
		end

		table.line()

		setTimeout(1000, function()
			--lbluetooth:close()
		end)
	end

	local ret = lbluetooth:scan(function(data)
		--console.log('scan', data)
		--console.printBuffer(data)

		if (#data <= 12) then
			return
		end

		local event_type 	= data:byte(6)
		local address_type 	= data:byte(7)
		local mac 			= data:sub(8, 13)
		local len 			= data:byte(14)
		local rssi 			= data:byte(#data) - 256

		mac = utils.bin2hex(mac)

		--console.printBuffer(mac)
		--console.log(event_type, mac, address_type, len, rssi)

		local beacon = beacons[mac]
		if (not beacon) then
			beacon = {}
			beacon.rssi = {}
			beacon.times = {}
			beacon.mac = mac
			beacons[mac] = beacon
		end

		beacon.rssi[#beacon.rssi + 1] = rssi
		if (#beacon.rssi % 10 == 0) then
			print(#beacon.rssi, rssi)
		end

		if (#beacon.rssi == 100) then
			stat(beacon)
		end
	end)

	if (ret < 0) then
		print('scan ret', ret)
		--lbluetooth:close()
	end
end

main()


