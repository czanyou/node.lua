local fs 	= require('fs')
local path  = require('path')
local url 	= require('url')
local utils = require('utils')

local basePath = process.cwd()
console.log('basePath', basePath)

--local source = path.dirname(debug.getinfo(1).short_src or '')
--basePath = path.join(process.cwd(), source)

function test_hls_writer()
	local dest = path.join(basePath, '../../bin/output.ts')
	os.remove(dest)

	local lmedia = require('lmedia')
	local tsReader = require('hls/reader')
	local lwriter = require('lmedia.ts.writer')

	console.log('lmedia', lmedia)
	local writer = lwriter.new()
	console.log('writer', writer, dest)

	local dest_fd = fs.openSync(dest, 'w', 438)

	writer:start(function(packet)
		--print('packet', type(packet), #packet)

		if (type(packet) == 'string') then
			fs.writeSync(dest_fd, -1, packet)
		end
	end)

	writer:writeSyncInfo(0)

--  [[
	local startPts = 0
	local lastPts = 0
	local duration = 0

	local reader = tsReader.StreamReader:new()
	reader:on('packet', function(packet, pts, sync, sps, pps)
		-- console.log('StreamReader')
		if (startPts <= 0) then
			startPts = pts
		end
		pts = pts - startPts
		duration = pts - lastPts
		lastPts = pts

		console.log('StreamReader', pts, duration)

		local sep = string.char(0, 0, 0, 1)

		local pos = 1
		while (true) do
			local next_pos = packet:find(sep, pos + 1)
			local data = packet:sub(pos, next_pos and next_pos - 1 or nil)
			--print(pos, next_pos, #data);
			--console.printBuffer(data:sub(1, 8))

			if (not next_pos) then
				--writer:write(data, pts, true)
				break
			else
				--writer:write(data, pts, false)
			end

			pos = next_pos
		end
		--console.printBuffer(packet:sub(1, 8))

		--print('stream', math.floor(pts / 1000), #packet, sync, sps or '', pps or '');
		writer:write(packet, pts)
	end)

	reader:on('end', function()
		console.log('stream end');

		writer:writeSyncInfo(0)
		writer:close()

		fs.closeSync(dest_fd)
		dest_fd = 0
	end)

	reader:on('start', function()
		console.log('stream start');
	end)

	local source = basePath .. '/examples/641.ts'
	local source_fd = fs.openSync(source, 'r', 438)

	reader:start()
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
	reader:close()


	fs.closeSync(source_fd)
	source_fd = 0

--]]

	setTimeout(100, function() end)
end

function test_hls2()
	console.log('basePath', basePath)

	local lmedia  = require('lmedia')
	local lwriter = require('lmedia.ts.writer')

	console.log(lmedia)

	local dest = basePath .. '/tmp/test.ts'
	console.log(dest)

	local writer = lwriter.new()
	console.log(writer)

	writer:start(function(packet, meta)
		--console.log('packet', packet, meta)
	end)

	local list = {}
	for i = 1, 100 do
		list[#list + 1] = "abcdefghijklmn1234567890"
	end
	local data = table.concat(list)

	writer:writeSyncInfo(40)

	local startTime = process.hrtime()
	for i = 1, 20000 do
		writer:write(data, 80)
	end
	local endTime = process.hrtime()
	print((endTime - startTime) / 1000000)

	writer:close()
end

console.log(arg)

local action = arg[1] or ''
if (action == 'b') then
	test_hls2()
else
	test_hls_writer()
end

run_loop()
