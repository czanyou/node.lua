local utils 	= require('utils')
local url 		= require('url')
local fs 		= require('fs')
local path  	= require('path')
local uv 		= require('uv')
local tap 		= require("ext/tap")
local assert 	= require('assert')
local m3u8  	= require('hls/m3u8')
local tsWriter 	= require('hls/writer')
local tsReader 	= require('hls/reader')

local basePath   = utils.dirname()
local testsPath  = path.dirname(basePath)
local visionPath = path.dirname(testsPath)
local rootPath   = path.dirname(visionPath)

local testFile   = path.join(rootPath, 'app/camera/examples/hd.ts')

return tap(function(test)

--[[

--]]
test('test_hls_writer', function()

	-- playList
	local playList = m3u8.newList()
	playList:setTargetDuration(1)
	playList:setMediaSequence(1)

	local m3u8file = path.join(rootPath, 'build/output2.m3u8')
	print('m3u8 filename: ', m3u8file)

	local _flushPlaylist = function(duration)
		playList:addItem(dest, duration / 1000000)
		fs.writeFile(m3u8file, playList:toString(), function()
			console.log('write m3u8 end');
		end)
	end

	-- writer
	local filename = path.join(rootPath, 'build/output2.ts')
	os.remove(filename)
	print('output filename: ', filename)

	local writer = tsWriter.StreamWriter:new()
	local dest = filename
	local dest_fd = fs.openSync(dest, 'w', 438)
	print('output fd: ', dest_fd)
	assert(dest_fd > 0)

	local _closeWriter = function()
		writer:close()

		fs.closeSync(dest_fd)
		dest_fd = 0		
	end

	-- start
	writer:start(function(packet, pts, flags)
		if (flags > 0) then
			--console.log('packet', pts, flags, #packet)
		end

		fs.writeSync(dest_fd, -1, packet)
	end)

	writer:writeSyncInfo(0)

	local startPts = 0
	local lastPts = 0
	local duration = 0

	writer:on('end', function()
		console.log('end', duration / 1000000)
		_flushPlaylist(duration)
	end)

	-- reader
	local reader = tsReader.StreamReader:new()
	reader:on('video', function(packet, pts, sync, sps, pps)
		if (startPts <= 0) then
			startPts = pts
		end
		pts = pts - startPts
		duration = pts - lastPts

		--print('stream', math.floor(pts / 1000), #packet, sync, sps or '', pps or '');
		writer:writeVideo(packet, pts)
	end)

	reader:on('audio', function(packet, pts, sync)
		if (startPts <= 0) then
			startPts = pts
		end
		pts = pts - startPts

		--print('stream', math.floor(pts / 1000), #packet, sync, sps or '', pps or '');
		writer:writeAudio(packet, pts)
	end)

	reader:on('end', function()
		console.log('stream stop read');
		_closeWriter()
	end)

	reader:on('start', function()
		console.log('stream start read');
	end)

	-- reader open
	local source = testFile
	print('source file: ', source)

	local source_fd = fs.openSync(source, 'r', 438)
	assert(source_fd > 0)

	reader:start()

	-- loop through TS packets
	while true do
		-- read a TS packet
		local chunk = fs.readSync(source_fd, tsWriter.TS_PACKET_SIZE)
		local ret = reader:processPacket(chunk)
		--console.log(ret, #chunk)
		if (ret < 0) then
			break;
		end
	end

	-- reader close
	reader:close()
	fs.closeSync(source_fd)
	source_fd = 0
end)

end)