local app   	= require('app')
local express   = require('vision/express')
local request   = require('vision/express/request')
local rpc   	= require('vision/express/rpc')
local server 	= require('vision/ssdp/server')
local utils 	= require('utils')
local path   	= require('path')
local json   	= require('json')
local lutils    = require('lutils')
local fs        = require('fs')
local uv 		= require("uv")
local gpio   	= require('vision/device/gpio')
local request   = require('vision/express/request')
local pprint    = utils.pprint
local bluetooth = require('vision/device/bluetooth')
local dirname   = path.dirname(utils.filename())

print(dirname)

--我的ibeacon的mac地址
-- local target   = 'ee231cd38e66'
local target   = 'e7e1a4dbc3d3'

local url 	   = 'http://iot.sae-sz.com:4000/device/data/report'
-- local url 	   = 'http://10.10.71.36:4000/device/data/report'
local time   = 1
local minute = 15
local repet  = 3

local SCAN_RESPONSE = 0x04

local exports = {}



local function generateMsg(device,t,h)
	local x = os.time()
	local data = device.key .. x
	local hash = lutils.md5(data)
	local hex_hash = lutils.hex_encode(hash)
	-- local msg = {
	-- 	device_id = device.id,
	-- 	key = x,
	-- 	hash = hex_hash,
	-- 	state = 
	-- 			{
	-- 				reported = {
	-- 				temperature = t,
	-- 				humidity = h
	-- 				},
	-- 				seq = 123,
	-- 				timestamp = x
	-- 			},
				
	-- 	version = 1.0			
	-- 	}
	-- return json.stringify(msg)
	local options = { form = { 
							device_id = device.id,
							hash 	  = hex_hash,
							key       = x,
							version   = 1.0,
							state     = '{"reported" : {"temperature" : ' .. t ..',"humidity" : ' .. h .. '},"seq" : 123,"timestamp" : ' .. x .. '}'  
							}}
	return options

end

local function getDeviceJson(basePath)
	local filename = path.join(basePath, "device.json")
	local data = fs.readFileSync(filename)
	return data and json.parse(data)
end

function publish(tempareture,humity)
	local device = getDeviceJson(dirname)
	if(device.id ~= nil)
		then
	-- 	utils.async(function()
	-- 		local msg = generateMsg(device,tempareture,humity)
	-- 		rpc.publish('/device/data',msg, 1,function(err, result)
	--             pprint('/device/data', err, result)
	--         end)
	-- 	end)	

		local options = generateMsg(device,tempareture,humity)
		request.post(url, options, function(err, response, body)
		    print(response.statusCode, body)
		end)

    end
end



function ble_scan(target, timeout, callback)

	local isStop = false;

	-- ble.reset();
	-- local fd = ble.open();

	-- print("fd = ", fd);

	-- if (fd < 0) then
	-- 	callback('err')
	-- 	return
	-- end

	local _onReadNext

	local index = 0
	local startTime = process.now()

	local interval = setInterval(3000, function()
		bluetooth.stopScan()
		-- ble.close()
		-- ble.reset();
		-- fd = ble.open();
	end)

	local timer = setTimeout(timeout, function()
		clearInterval(interval)

		-- ble.close()
		isStop = true
		-- callback('timeout')
		return
	end)

	_onReadNext = function()

		-- body
		-- print('start fs read')
		bluetooth.startScan(function(err, ret)

			if isStop then
				bluetooth.stopScan()
				callback('timeout')
				return
			end

			-- console.log(err, ret)

			--console.log(ret)
			if err then 
				clearTimeout(timer)
				clearInterval(interval)

				bluetooth.stopScan()
				callback(nil, ret)
				return
			end
			local mac  = ret:sub(8,13):reverse()
			mac = utils.bin2hex(mac)
			-- console.printBuffer(ret)

			if ret:byte(6) ~= 0x04 then
				-- print('stop')
				_onReadNext()
				return
			end
			
			print('mac = ', mac)
	
			local length = ret:byte(15)
			local flag1  = ret:byte(16)
			local flag2  = ret:byte(17)
			local flag3  = ret:byte(18)

			if (target and target ~= mac) then
				-- print('stop')
				_onReadNext()
				return
			end

			if (flag1 == 0xff) then
				clearTimeout(timer)
				clearInterval(interval)

				bluetooth.stopScan()
				callback(nil, ret)
				-- print('stop')
				return
			end
			-- print('stop')
			_onReadNext()
		end)
	end

	_onReadNext()
end	



function exports.help()
	print([[

usage:sudo lpm ibeacon <command> 

- scan 

]])
end



local onData = function(err, data)
    if (not data) then
        --if err then console.log(err) end
        return
    end

    -- console.log('startScan', data)

    local mac  = data:sub(8,13):reverse()
		  mac  = utils.bin2hex(mac)

    if data:byte(6) ~= SCAN_RESPONSE then
        return
    end
        
    local length = data:byte(15)
    local flag1  = data:byte(16)
    local flag2  = data:byte(17)
    local flag3  = data:byte(18)

    if (target and target ~= mac) then
				return
			end

    if (flag1 ~= 0xff) then
        return
    end

    console.printBuffer(data)

	local temp = data:byte(19) .. "." .. data:byte(20)
	local humity = data:byte(21) .. "." .. data:byte(22)
	print('temp = ', temp)
	print('humity = ', humity)
	bluetooth.stopScan()
	publish(temp,humity)
	print('stop scan...')
end

function on_timer()
	-- 计数 15分钟才执行一次
	time = time + 1
	print(time)
	if time >= minute then
		time = 1
		print('start scan')
		bluetooth.startScan(onData)
		setTimeout(60000*3, function()
		    bluetooth.stopScan()
		    print('stop scan...')
		end)

		-- ble_scan(target, 1000 * 60, function(err, ret)
		-- 	console.log('scan', err)

		-- 	if err then
		-- 		-- 发生错误 则重复扫描最多3次
		-- 		repet = repet - 1
		-- 		go_repet()
		-- 		return
		-- 	end

		-- 	if (ret) then
		-- 		console.printBuffer(ret)

		-- 		local temp = ret:byte(19) .. "." .. ret:byte(20)
		-- 		local humity = ret:byte(21) .. "." .. ret:byte(22)
		-- 		print('temp = ', temp)
		-- 		print('humity = ', humity)
		-- 		repet = 3
		-- 		time  = 1
		-- 		publish(temp,humity)
		-- 	end
		-- end)
	end
end

function go_repet()
	-- 如果重复3次 则退出
	if (repet < 0 or repet == 0) then
		repet = 3
		time  = 1
	else
		ble_scan(target, 1000 * 60, function(err, ret)
			console.log('scan', err)

			if err then
				-- 发生错误 则重复扫描最多3次
				repet = repet - 1
				time  = minute
				go_repet()
				return
			end

			if (ret) then
				console.printBuffer(ret)

				local temp = ret:byte(19) .. "." .. ret:byte(20)
				local humity = ret:byte(21) .. "." .. ret:byte(22)
				print('temp = ', temp)
				print('humity = ', humity)
				repet = 3
				time  = 1
				publish(temp,humity)
			end
		end)
	end
end



function exports.start()
	-- bluetooth.startScan(onData)
	-- 	setTimeout(60000, function()
	-- 	    bluetooth.stopScan()
	-- 	    print('stop scan...')
	-- 	end)	
	-- repet = 3
	time  = 1
	setInterval(1000 * 60, on_timer)
end

function exports.daemon()
	-- local filename = utils.filename()
 --    local cmdline  = "sudo lnode -d " .. filename .. " start"
 --    print('deamon', cmdline)
 --    os.execute(cmdline)
    app.daemon()
end

app(exports)

-- publish(12,12)
-- local device = getDeviceJson(dirname)
-- pprint(device.id)
-- local object = getDeviceJson(dirname)
-- pprint(object)

-- utils.async(function()
-- 	local device = getDeviceJson(dirname)
-- 	local msg = generateMsg(device)
-- 	pprint(msg)
-- 	end)	
