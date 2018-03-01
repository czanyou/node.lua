local app       = require('app')
local utils     = require('util')
local fs        = require('fs')
local path      = require('path')
local json      = require('json')
local request   = require('http/request')


local exports 		= {}
local beaconList 	= {}

local MAX_MESSAGE_COUNT 	= 1000
local DEFAULT_ENV_FACTOR	= 3.5

local PROFILE_IBEACON             		= 1
local PROFILE_IBEACON_TEST             	= 10
local PROFILE_QUUPPA                    = 2
local PROFILE_EDDYSTONE_TLM             = 3
local PROFILE_EDDYSTONE_TLM_RSSI        = 4
local PROFILE_EDDYSTONE_TLM_SENSOR      = 5
local PROFILE_EDDYSTONE_TLM_CUSTOMIZE   = 6

exports.REST_URL 	= ''

exports.settings   	= {}

function table.deepcopy(object)
    local lookup_table = {}
	local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

function table.assign(first_table, second_table)
	for k,v in pairs(second_table) do 
		first_table[k] = v 
	end
end

function exports.clearInvalidBeacons()
    local now = os.time()
    local count = 0

    local settings = exports.settings or {}
	local stat_timeout = tonumber(settings.stat_timeout or 5) or 5


	local beacons = beaconList
	for mac, beacon in pairs(beacons) do
		local span = math.abs(now - beacon.updated)
		if (span > stat_timeout) then
			beaconList[mac] = nil
			count = count + 1
		end
	end

	return count
end

-- 上报beacon的rssi数据
function exports.postData()
    local device_key = exports.settings.device_key or ''
    local device_id  = exports.settings.device_id  or ''
	local pkey = exports.settings.pkey or ''

	-- device_id = '123456'
	-- device_key = 'test'
	-- exports.settings.collector = '192.168.2.15:3000'

	if (not device_id) or (device_id == '') then
		print('device_id is empty')
		return
	end

	local list = {}

	local encodeBeacon = function (beacon)
		local buf = table.deepcopy(beacon)
		if beacon.rssi then
			local rssi_string = ''
			for i, rssi in pairs(beacon.rssi) do
				rssi_string = rssi_string .. string.char(rssi + 256)
				-- console.log(rssi)
			end
			buf.rssi = utils.base64Encode(rssi_string)
		end
		--if beacon.profile == PROFILE_IBEACON_TEST then 
		--	console.log(beacon.tid)
		--	console.log(buf)
		--end
		return buf
	end

	-----------------------parse and copy beaconList---------------------
	local beacons = beaconList
	for tid, beacon in pairs(beacons) do
		list[#list + 1] = encodeBeacon(beacon)
	end

	-----------------------clear beaconList---------------------
	beaconList = {}
	-- console.log(list)

	-- form
	local timestamp = tonumber(os.time() .. '000')
	local nonce = 'anb03f'
	local value = nonce .. ':' .. timestamp .. ':' .. device_key
	local sign 	= utils.bin2hex(utils.md5(value))
	local mac 	= ''

	local form = {
		id 			= device_id,
		pkey		= pkey,
		at 			= timestamp,
		nonce		= nonce,
		sign 		= sign,
	  	data 		= list
	}

	-- console.log(form)

	local server = exports.settings.collector or '127.0.0.1'
	-- local server = '192.168.1.2:8901'

	-- post
	local data = json.stringify(form)
	-- console.log(data)
	local options = { data = data, contentType = 'application/json' }
	local urlString = server .. '/beacon/pushRaw'
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
	local server = 'nms.beaconice.cn:3000'

	local urlString = server .. '/register'
	if (not urlString:startsWith('http:')) then
		urlString = 'http://' .. urlString
	end

	local form = { mac = id ,model = "Intel", version = process.version, target = "Intel"}
	local data = json.stringify(form)
	local options = { data = data, contentType = 'application/json' }

	-- console.log(urlString, options)

	request.post(urlString, options, function(error, response, body)
		if (error) then
			console.log(error)
			callback({error = error})
			return
		end

		local result = json.parse(body) or {}
		-- console.log(body)
		if result.result == 0 then
			settings.collector  = result.config.http_url or '127.0.0.1'
			if (result.key) then
				settings.device_id  = id
				settings.device_key = result.key
			end
			callback({error = nil, data = body})
		else
			callback({error = (result.error or 'error'), data = nil})
		end
	end)
end

function exports.getList()
	
	local list = {}

	for mac, item in pairs(beaconList) do
		local data = {}
		-- data.uuid 		= item.uuid
		-- data.mac  		= item.mac
		-- data.major  	= item.major
		-- data.minor  	= item.minor
		-- data.rssi  		= item.rssi
		-- data.map  		= item.map
		-- data.distance  	= item.distance
		-- data.updated  	= item.updated
		-- data.power  	= item.power

		list[#list + 1] = data
	end
	return list
end

function exports.handleMessage(message)
	if (not message) or (not message.tid) then
		return
	end

	if message.profile then
		local beacon_id = message.tid .. '_' .. message.profile
		local beacon = beaconList[beacon_id]					-- search beaconList
		if (not beacon) then
			-- beacon = message
			if message.profile == PROFILE_IBEACON or message.profile == PROFILE_IBEACON_TEST or message.profile == PROFILE_EDDYSTONE_TLM_RSSI then
				beacon = message				
				local rssi = {}
				rssi[#rssi + 1] = message.rssi
				beacon.rssi = rssi
			elseif message.profile == PROFILE_QUUPPA then
			
			elseif message.profile == PROFILE_EDDYSTONE_TLM or message.profile == PROFILE_EDDYSTONE_TLM_SENSOR or message.profile == PROFILE_EDDYSTONE_TLM_CUSTOMIZE then
				beacon = message
			else
			end
			beaconList[beacon_id] = beacon
		else
			if message.profile == PROFILE_IBEACON or message.profile == PROFILE_IBEACON_TEST or message.profile == PROFILE_EDDYSTONE_TLM_RSSI then
				local rssi = beaconList[beacon_id].rssi
				table.assign(beaconList[beacon_id], message)
				if not rssi then
					rssi = {}					
				end
				rssi[#rssi + 1] = message.rssi
				beaconList[beacon_id].rssi = rssi
			elseif message.profile == PROFILE_EDDYSTONE_TLM or message.profile == PROFILE_EDDYSTONE_TLM_SENSOR or message.profile == PROFILE_EDDYSTONE_TLM_CUSTOMIZE then
				table.assign(beaconList[beacon_id], message)
			end
		end
	end
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
	end
    -- elseif (ADflag2 ~= 0x06) and (ADflag2 ~= 0x1A) then
    --     return
    -- end

    -- Byte 3-29: Apple Defined beacon Data
    -- find advertive packet
    local beaconlength     = data:byte(offset + 3) -- Byte 3: Length: 0x1a
    local manufactureData   = data:byte(offset + 4) -- Byte 4: Type: 0xff (Custom Manufacturer Packet)
    if (manufactureData ~= 0xFF) and (manufactureData ~= 0x03) and (manufactureData ~= 0x16) then
        return
    end

    local manufacturer1 = data:byte(offset + 5) -- Byte 5-6: Manufacturer ID : 0x4c00 (Apple)
    local manufacturer2 = data:byte(offset + 6)
    
    local now = tonumber(os.time() .. '000')

    local beacon = {}
    
	--------------------------------------------- iBeacon ---------------------------------------------
	if (manufacturer1 == 0x4c) and (manufacturer2 == 0x00) then
		local beaconFlag = data:byte(offset + 7) 	-- Byte 7: SubType: 0x02 (iBeacon)
		if (beaconFlag ~= 0x02) then
			return
		end

		local uuidLen = data:byte(offset + 8)		-- Byte 8: SubType Length: 0x15
		local uuid = data:sub(offset + 9, offset + 9 + 15) 	-- Byte 9-24: Proximity UUID
											-- Byte 25-26: Major
											-- Byte 27-28: Minor
											-- Byte 29: Signal Power
		local major, minor, power = string.unpack(">I2I2B", data, offset + 10 + 15)

		beacon.tid         	= string.lower(exports.parseMACAddress(data))
		beacon.at   		= now
		beacon.rssi     	= data:byte(#data) - 256
		beacon.uuid        	= utils.bin2hex(uuid)
		beacon.major       	= major
		beacon.minor       	= minor
		beacon.rssi1m      	= power - 256
		-- beacon.profile		= PROFILE_IBEACON

		if(beacon.uuid == 'eaf1773092124b15b5a595b25beabccd') then -- assets beacon
			beacon.flagStatus	= data:byte(offset + 25)
			beacon.sos			= ((data:byte(offset + 26) >> 7) & 0x1)
			beacon.battery		= (data:byte(offset + 26) & 0x7f) / 1
			beacon.profile		= PROFILE_IBEACON_TEST
		elseif (beacon.uuid == 'fda50693a4e24fb1afcfc6eb07647825') then -- tour beacon
			beacon.profile		= PROFILE_IBEACON
		end
	------------------------------------------ Eddystone TLM ------------------------------------------	
	elseif (manufacturer1 == 0xaa) and (manufacturer2 == 0xfe) then
		local flag_ad_type 	= data:byte(offset + 8)
		local company_id 	= (data:byte(offset + 9) << 8) + data:byte(offset + 10)
		local frame_type 	= data:byte(offset + 11)
		
		if flag_ad_type == 0x16 then
		
			if company_id == 0xaafe then													-- standard
			-- console.log(string.lower(exports.parseMACAddress(data)))
				beacon.tid      	= string.lower(exports.parseMACAddress(data))
				beacon.profile		= PROFILE_EDDYSTONE_TLM
				beacon.at   		= now
				beacon.battery 		= (data:byte(offset + 13) << 8) + data:byte(offset + 14)
				beacon.temperature 	= data:byte(offset + 15) + (data:byte(offset + 16) / 256)
				beacon.adv_cnt 		= ((data:byte(offset + 17) << 24) + (data:byte(offset + 18) << 16) + (data:byte(offset + 19) << 8) + data:byte(offset + 20))
				beacon.sec_cnt 		= ((data:byte(offset + 21) << 24) + (data:byte(offset + 22) << 16) + (data:byte(offset + 23) << 8) + data:byte(offset + 24))
				-- beacon.payload		= data:sub(offset, #data)
				beacon.payload      = utils.bin2hex(data:sub(offset, #data))
			elseif company_id == 0xccfe then												-- expand
				if (frame_type == 0x20) then				-- location
					beacon.tid         	= string.lower(exports.parseMACAddress(data))
					beacon.profile		= PROFILE_EDDYSTONE_TLM_RSSI
					beacon.at   		= now
					beacon.rssi     	= data:byte(#data) - 256
					beacon.battery 		= ((data:byte(offset + 13) << 8) + data:byte(offset + 14))
					beacon.temperature = ((data:byte(offset + 15) << 8) + (data:byte(offset + 16)))
				elseif (frame_type == 0xfe) then			-- sensor
					beacon.tid         	= string.lower(exports.parseMACAddress(data))
					beacon.profile		= PROFILE_EDDYSTONE_TLM_SENSOR
					beacon.at   		= now
					beacon.payload 		= data:sub(offset, #data)
				elseif (frame_type == 0xfd) then			-- customize
					beacon.tid         	= string.lower(exports.parseMACAddress(data))
					beacon.profile		= PROFILE_EDDYSTONE_TLM_CUSTOMIZE
					beacon.at   		= now
					beacon.payload 		= data:sub(offset, #data)
				end
			else
			end
		end
	end
    return beacon
end

return exports
