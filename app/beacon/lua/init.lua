local app       = require('app')
local utils     = require('utils')
local fs        = require('fs')
local path      = require('path')
local json      = require('json')
local request   = require('http/request')


local exports 		= {}
local ibeaconList 	= {}

local MAX_MESSAGE_COUNT 	= 1000
local DEFAULT_ENV_FACTOR	= 3.5

exports.REST_URL 	= ''

exports.settings   	= {}

function exports.clearInvalidBeacons()
    local now = os.time()
    local count = 0

    local settings = exports.settings or {}
	local stat_timeout = tonumber(settings.stat_timeout or 5) or 5


	local beacons = ibeaconList
	for mac, beacon in pairs(beacons) do
		local span = math.abs(now - beacon.updated)
		if (span > stat_timeout) then
			ibeaconList[mac] = nil
			count = count + 1
		end
	end

	return count
end

function exports.postData()
    local device_key = exports.settings.device_key or ''
    local device_id  = exports.settings.device_id  or ''

	if (not device_id) or (device_id == '') then
		print('device_id is empty')
		return
	end

	local list = {}

	local encodeBeacon = function (beacon)
		return {
			tid       = beacon.mac, 
			distance  = math.floor(beacon.distance * 100) / 100, 
			at 		  = beacon.updated * 1000
		}
	end

	local beacons = ibeaconList
	for mac, beacon in pairs(beacons) do
		--if (beacon.timeOffset < TIME_OFFSET) then
			list[#list + 1] = encodeBeacon(beacon)
		--end
	end

	-- form
	local timestamp = os.time() .. '000'
	local nonce = 'anb03f'
	local value = nonce .. ':' .. timestamp .. ':' .. device_key
	local sign 	= utils.bin2hex(utils.md5(value))
	local mac 	= ''

	local form = {
	  id 		= device_id,
	  timestamp = timestamp,
	  nonce		= nonce,
	  mac 		= mac,
	  sign 		= sign,
	  data 		= list
	}

	--console.log(form)

	local server = exports.settings.collector or '127.0.0.1'

	-- post
	local data = json.stringify(form)
	local options = { data = data, contentType = 'application/json' }
	local urlString = server .. '/beacon/push'
	if (not urlString:startsWith('http:')) then
		urlString = 'http://' .. urlString
	end

	request.post(urlString, options, function(error, response, body)
		if (error) then
			console.log(error, urlString)
			return
		end

		local result = json.parse(body) or {}
		if (result.code ~= 0) then
			console.log(response.statusCode, result, urlString)
		end
	end)
end

-- 设备注册, 获取自己的 ID 和 Key, 以及采集服务器的地址
function exports.register(id, callback)
	local settings = exports.settings
	local server = settings.server or '192.168.1.2:8903'

	local urlString = server .. '/device/get'
	if (not urlString:startsWith('http:')) then
		urlString = 'http://' .. urlString
	end

	local form = { id = id }
	local data = json.stringify(form)
	local options = { data = data, contentType = 'application/json' }

	--console.log(urlString, options)

	request.post(urlString, options, function(error, response, body)
		if (error) then
			console.log(error)
			callback(error)
			return
		end

		local result = json.parse(body) or {}
		local data = result.data or {}

		--console.log(body)

		settings.collector  = data.collector or '192.168.1.2:8901'

		if (data.key) then
			settings.device_id  = id
        	settings.device_key = data.key
        end

        --console.log(data)
        --console.log(settings)
		
		callback(nil, data)
	end)
end

function exports.getList()
	
	local list = {}

	for mac, item in pairs(ibeaconList) do
		local data = {}
		data.uuid 		= item.uuid
		data.mac  		= item.mac
		data.major  	= item.major
		data.minor  	= item.minor
		data.rssi  		= item.rssi
		data.map  		= item.map
		data.distance  	= item.distance
		data.updated  	= item.updated
		data.power  	= item.power

		list[#list + 1] = data
	end
	return list
end

function exports.distance(rssi, power)
	rssi = math.abs(rssi)

	local settings = exports.settings or {}
	local factor = tonumber(settings.stat_factor) or DEFAULT_ENV_FACTOR
	local pow = (rssi + power) / (10 * factor);
    local distance = 10 ^ pow

    if (distance > 0 and distance <= 4) then
        distance = (1 / 4) * (distance ^ 2)
    end
  
	return distance
end

function exports.getAvgFramerate(messages, index)
	if (not messages) or (#messages < 1) then
		return 0
	end

	local pos = (index % MAX_MESSAGE_COUNT) + 1
	local message = messages[pos] or {}
	local endTime = message.timestamp or 0

	local count = 1
	local framerate = 0
	while (index > 1) do
		index = index - 1
		count = count + 1

		pos = (index % MAX_MESSAGE_COUNT) + 1
		message = messages[pos] or {}

		local span = endTime - (message.timestamp or 0)
		if (count >= 10 and span > 0) or (span > 3) then
			framerate = math.floor(count / span + 0.5)
			--print('framerate', count, span, framerate)
			break
		end
	end

	return framerate
end


function exports.handleMessage(message)
	if (not message) or (not message.mac) then
		return
	end

	local ibeacon = ibeaconList[message.mac]
	if (not ibeacon) then
		ibeacon = message

		ibeaconList[message.mac] = ibeacon
	end

	if (not ibeacon.messages) then
		ibeacon.messages = {}
	end

	if (not ibeacon.map) then
		ibeacon.map = {}
	end	


	local settings = exports.settings or {}
	--console.log(settings)

	local MAX_STAT_COUNT = tonumber(settings.stat_max_count or 20) or 20
	local MAX_STAT_TIME  = tonumber(settings.stat_max_time  or 3 ) or 3

	--print("settings", MAX_STAT_COUNT, MAX_STAT_TIME)

	local item = {}
	item.rssi 			= message.rssi
	item.timestamp 		= message.timestamp

	local index  = ibeacon.index or 1

	-- 
	local offset = ibeacon.offset or 1
	while (offset < index - MAX_STAT_COUNT) do
		local pos = (offset % MAX_MESSAGE_COUNT)
		local oldItem = ibeacon.messages[pos]
		if (oldItem) then
			local span = message.timestamp - oldItem.timestamp
			if (span <= MAX_STAT_TIME) then
				break
			end

			local value = (ibeacon.map[oldItem.rssi] or 0) - 1
			--print('oldItem', oldItem.rssi, value, offset, index)

			if (value <= 0) then value = nil end
			ibeacon.map[oldItem.rssi] = value
		end

		ibeacon.messages[pos] = nil
		offset = offset + 1
	end

	if (item) then
		local rssi = item.rssi or 0
		local value = (ibeacon.map[rssi] or 0) + 1
		ibeacon.map[rssi] = value
	end

	local maxValue = 0
	local maxRssi  = -300
	for rssi, value in pairs(ibeacon.map) do
		if (maxValue < value) then
			maxValue = value
			maxRssi  = rssi
		end
	end

	local pos = (index % MAX_MESSAGE_COUNT) + 1
	ibeacon.messages[pos] = item
	ibeacon.index 		= index + 1
	ibeacon.offset 		= offset
	ibeacon.framerate   = exports.getAvgFramerate(ibeacon.messages, index)
	ibeacon.updated 	= message.timestamp
	ibeacon.distance	= exports.distance(maxRssi, message.power)
end


function exports.parseMACAddress(data, offset)
	offset = offset or 8
	local list = {}
	for i = 1, 6 do
		list[#list + 1] = string.format("%02X", data:byte(offset + 6 - i))
	end
	return table.concat(list)
end


function exports.parseBeaconMessage(data)
	local offset = 15

	-- Packet Structure Byte Map
	-- Byte 0-2: Standard BLE Flags
    local ADlength = data:byte(offset + 0)  -- Byte 0: Length :  0x02
    local ADflag1  = data:byte(offset + 1)  -- Byte 1: Type: 0x01 (Flags)
    local ADflag2  = data:byte(offset + 2)  -- Byte 2: Value: 0x06 (Typical Flags)

    if (ADlength ~= 0x02) or (ADflag1 ~= 0x01) then
        return

    elseif (ADflag2 ~= 0x06) and (ADflag2 ~= 0x1A) then
        return
    end

    -- Byte 3-29: Apple Defined iBeacon Data
    -- find advertive packet
    local iBeaconlength     = data:byte(offset + 3) -- Byte 3: Length: 0x1a
    local manufactureData   = data:byte(offset + 4) -- Byte 4: Type: 0xff (Custom Manufacturer Packet)
    if (manufactureData ~= 0xFF) then
        return
    end

    local manufacturer1 = data:byte(offset + 5) -- Byte 5-6: Manufacturer ID : 0x4c00 (Apple)
    local manufacturer2 = data:byte(offset + 6)
  
    local ibeaconFlag = data:byte(offset + 7) 	-- Byte 7: SubType: 0x02 (iBeacon)
    if (ibeaconFlag ~= 0x02) then
        return
    end

    local uuidLen = data:byte(offset + 8)		-- Byte 8: SubType Length: 0x15
    local uuid = data:sub(offset + 9, offset + 9 + 15) 	-- Byte 9-24: Proximity UUID
    									-- Byte 25-26: Major
 										-- Byte 27-28: Minor
 										-- Byte 29: Signal Power
    local major, minor, power = string.unpack(">I2I2B", data, offset + 10 + 15)
    local now = os.time()

    local ibeacon = {}
    ibeacon.mac         = exports.parseMACAddress(data)
    ibeacon.rssi     	= data:byte(#data) - 256
    ibeacon.timestamp   = now
    ibeacon.uuid        = utils.bin2hex(uuid)
    ibeacon.major       = major
    ibeacon.minor       = minor
    ibeacon.power       = power - 256
	if ibeacon.uuid == 'fda50693a4e24fb1afcfc6eb07647825' then
		ibeacon.mac = 'FFFFFFFF' .. string.format('%4X', ibeacon.minor)
	end
    return ibeacon
end

return exports
