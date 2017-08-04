local ble 		= require('lbluetooth')
local fs  		= require('fs')
local thread 	= require('thread')

function start_le_scan()
	local ble 		= require('lbluetooth')
	local fs  		= require('fs')

	ble.reset()

	local deviceHandler = ble.open()

	print("bluetooth device = ", deviceHandler)

	for i = 1, 1000 do
		local ret = fs.readSync(deviceHandler)
		console.printBuffer(ret)

		--console.log(ret)
		if ret:byte(6) == 0x04 then
			
			local length = ret:byte(15)
			local flag1 = ret:byte(16)

			if (flag1 == 0xff) then
				--console.printBuffer(ret)
				local temp = ret:byte(19) .. "." .. ret:byte(20)
				local humi = ret:byte(21) .. "%"

				temp = (math.floor(temp * 10) / 10) .. '`C'
				print(temp, humi)
			end
		end
	end

	ble.close()
end

local work = thread.work(start_le_scan, function(...)
	console.log(...)
end)

work:queue()

