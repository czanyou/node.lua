local utils 	= require('util')
local fs 		= require('fs')
local path  	= require('path')
local assert 	= require("assert")
local tap 		= require("ext/tap")
local lmedia 	= require("lmedia")
local lreader 	= require("lmedia.ts.reader")

local basePath  = utils.dirname()

local test = tap.test

-- 这个测试将从 TS 流中分离出单纯的 ES 流

test('test_hls_reader', function()

	local filename = path.join(basePath, '../../app/camera/examples/hd.ts')
	local fileData = fs.readFileSync(filename)

	print('source ts file: ' .. filename)
	print('source ts file length: ' .. #fileData)

	local fileSize = #fileData

	local list   	 = {}
	local sample 	 = {}
	local sampleSize = 0


	local audioSize  = 0

	local lastTime   = 0

	console.log(lreader)
	
	local output = {}
	local adts = {}

	local reader = nil
	reader = lreader.open(function(sampleData, sampleTime, flags)
		if ((flags & lreader.FLAG_IS_AUDIO) ~= 0) then
			table.insert(adts, sampleData)
			return
		end

		table.insert(output, sampleData)

		--print('flags', flags)

		sampleSize = sampleSize + #sampleData

		if (flags & lreader.FLAG_IS_SYNC) ~= 0 then
			lastTime = sampleTime

			if (sampleSize > 0) then
				list[#list + 1] = sampleSize

				console.log('sample', lastTime, sampleSize)
			end

			sampleSize = 0
		end

		--console.log(sampleTime, flags)
		--console.printBuffer(sampleData)
	end)

	local offset = 1
	local chunkSize = 1024
	while (true) do
		local packet = fileData:sub(offset, offset + chunkSize - 1)
		if (not packet) then
			break
		end

		reader:read(packet, 0)

		offset = offset + chunkSize
		if (offset > fileSize) then
			break
		end
	end

	reader:close()

	local data = table.concat(output)

	local filename = path.join(basePath, '../build/output1.h264')
	fs.writeFileSync(filename, data)

	print('output es file: ' .. filename)
	print('output es file length: ' .. #data)

	local data = table.concat(adts)

	local filename = path.join(basePath, '../build/output1.aac')
	fs.writeFileSync(filename, data)

	print('output es file: ' .. filename)
	print('output es file length: ' .. #data)


end)

tap.run()
