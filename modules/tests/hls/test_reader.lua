local utils 	= require('utils')
local url 		= require('url')
local fs 		= require('fs')
local path  	= require('path')
local assert 	= require("assert")
local tap 		= require("ext/tap")
local hlsReader = require('hls/reader')

local basePath   = utils.dirname()
local testsPath  = path.dirname(basePath)
local visionPath = path.dirname(testsPath)
local rootPath   = path.dirname(visionPath)

local testFile   = path.join(rootPath, 'app/camera/examples/hd.ts')

local TS_PACKET_SIZE = hlsReader.TS_PACKET_SIZE

local function loadSourceData()
	-- file data
	local filename = testFile
	local fileData = fs.readFileSync(filename) or ''
	local fileSize = #fileData
	print('input: ' .. filename .. ' (' .. fileSize .. 'Bytes).')

	return fileData
end

local function writeH264Data(output)
	local data = table.concat(output)
	local filename = path.join(basePath, '../../../build/output0.h264')
	print('output: ' .. filename .. ' (' .. #data .. 'Bytes, ' .. #output .. 'Packets).')
	
	fs.writeFileSync(filename, data)

	assert.equal(#output, 224)
end

local function writeAACData(output)
	local data = table.concat(output)
	local filename = path.join(basePath, '../../../build/output0.aac')
	print('output: ' .. filename .. ' (' .. #data .. 'Bytes, ' .. #output .. 'Packets).')
	
	fs.writeFileSync(filename, data)
end

return tap(function(test)

test('test_hls_reader', function()
	-- 这个测试程序将解析指定的源 TS 流文件，并输出 H.264 ES 流文件

	local startPts = 0
	local lastPts  = 0
	local duration = 0

	local output = {}
	local adts = {}

	local reader = hlsReader.StreamReader:new()

	reader:on('audio', function(packet, sampleTime, syncPoint)
		print('audio', sampleTime)

		console.printBuffer(packet)

		table.insert(adts, packet)
	end)

	reader:on('video', function(packet, sampleTime, syncPoint)
		print('video', sampleTime)

		if (startPts <= 0) then
			startPts = sampleTime
		end

		local pts = sampleTime - startPts
		duration = pts - lastPts
		lastPts = pts

		--console.log('test_hls_reader', syncPoint, pts, duration, #packet)

		table.insert(output, packet)
	end)

	reader:on('end', function()
		print('ts stream read end');

		writeH264Data(output)
		writeAACData(adts)
	end)

	reader:on('start', function()
		print('ts stream read start');
	end)

	reader:start()

	local fileData = loadSourceData()
	local fileSize = #fileData

	local offset = 1
	while (true) do
		local packet = fileData:sub(offset, offset + TS_PACKET_SIZE - 1)
		if (not packet) then
			break
		end

		reader:processPacket(packet)

		offset = offset + TS_PACKET_SIZE
		if (offset > fileSize) then
			break
		end

		if (reader.sampleIndex and reader.sampleIndex > 1000) then
			break
		end
	end

	reader:close()

end)

end)

