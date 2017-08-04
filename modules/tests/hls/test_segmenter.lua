local path  	= require('path')
local utils 	= require('utils')
local url   	= require('url')
local fs    	= require('fs')
local uv 		= require('uv')
local tap 		= require("ext/tap")

local segmenter = require('hls/segmenter')
local tsReader	= require('hls/reader')

local platform 	= os.platform()

local basePath 	= utils.dirname()
if (platform == 'Windows') then
	segmenter.basePath = basePath .. '\\tmp\\live'
end

local function test_media_source()
	console.log('basePath', basePath)


	local hlsSegmenter = segmenter.newSegmenter()

	local baseTime = 0
	local lastTime = 0
	local startPts = 0

	local reader = tsReader.StreamReader:new()
	reader:on('packet', function(packet, pts, sync, sps, pps)
		if (startPts == 0) then
			startPts = pts
		end
		pts = pts - startPts

		local sampleTime = baseTime + pts
		if (sampleTime < lastTime) then
			baseTime = lastTime
			sampleTime = baseTime + pts
		end

		--print('ts', pts, baseTime, lastTime, sampleTime)
		hlsSegmenter:push(packet, sampleTime, sync, sps, pps)
		lastTime = sampleTime
	end)

	reader:on('end', function()
		console.log('stream end');
		hlsSegmenter:stop()
	end)

	reader:on('start', function()
		console.log('stream start');
		hlsSegmenter:start()
	end)

	reader:start()
	for i = 1,3 do
		local filename = path.join(basePath, '../../examples.ts')
		if (not fs.existsSync(filename)) then
			print('not exists: ', filename)
			break;
		end

		local source_fd = fs.openSync(filename, 'r', 438)
	
		-- loop through TS packets
		while true do
			-- read a TS packet
			local chunk = fs.readSync(source_fd, tsReader.TS_PACKET_SIZE)
			local ret = reader:processPacket(chunk)
			--console.log(ret, #chunk)
			if (ret < 0) then
				break;
			end
		end

		fs.closeSync(source_fd)
		source_fd = 0

	end
	reader:close()
end

run_loop()

