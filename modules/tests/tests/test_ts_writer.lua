local utils 	= require('utils')
local fs 		= require('fs')
local path  	= require('path')
local assert 	= require("assert")
local tap 		= require("ext/tap")
local lmedia 	= require("lmedia")

local lreader 	= require("lmedia.ts.reader")
local lwriter 	= require("lmedia.ts.writer")


local basePath  = utils.dirname()

function loadMediaStream()
	local filename = path.join(basePath, '../../app/camera/examples/hd.ts')
	local fileData = fs.readFileSync(filename)
	local fileSize = #fileData

	print('source ts file: ' .. filename)
	print('source ts file length: ' .. #fileData)

	--console.log(lreader)
	
	local video  = nil
	local audio  = nil

	local list  = {}

	local reader = nil
	reader = lreader.open(function(sampleData, sampleTime, flags)
		if (flags & lreader.FLAG_IS_AUDIO) ~= 0 then

			if (flags & lreader.FLAG_IS_START) ~= 0 then
				if (audio) then
					table.insert(list, audio)
				end

				audio  = {sampleTime = sampleTime, flags = flags}
			end

			table.insert(audio, sampleData)
		
		else

			if (flags & lreader.FLAG_IS_START) ~= 0 then
				if (video) then
					table.insert(list, video)
				end

				video  = {sampleTime = sampleTime, flags = flags}
				--print(#sampleData, sampleTime, flags)
			end

			table.insert(video, sampleData)

		end

		--
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

	print('output es length: ' .. #list)

	console.log(list[2].sampleTime)

	return list
end

return tap(function(test)

-- 这个测试将从 TS 流中分离出单纯的 ES 流

test('test_hls_reader', function()
	local list = loadMediaStream()

	local output = {}

	local writer = nil
	writer = lwriter.open(function(packet, time, flags)
		if (flags & 0x8000) ~= 0 then
			--console.log(time, flags)
		end

		output[#output + 1] = packet;
	end)

	for i = 1, #list do
		local sample = list[i]
		local sampleData = table.concat(sample)
		local sampleTime = sample.sampleTime
		local flags      = sample.flags

		--console.printBuffer(sampleData)

		--print('sample', #sampleData, sampleTime, flags)
		writer:write(sampleData, sampleTime, flags)
	end

	writer:close()


	local data = table.concat(output)

	local filename = path.join(basePath, '../build/output3.ts')
	fs.writeFileSync(filename, data)

	print('output ts file: ' .. filename)
	print('output ts file length: ' .. #data)

end)

end)
