local utils   	= require('utils')
local lmedia  	= require('lmedia')
local thread  	= require('thread')
local uv     	= require('uv')
local path     	= require('path')
local fs     	= require('fs')

local testsPath  = utils.dirname()
local mediaPath  = path.dirname(testsPath)
local rootPath   = path.dirname(mediaPath)

local filename = path.join(mediaPath, 'build/output1.aac')
local outfile  = path.join(mediaPath, 'build/output2.wav')
local pcmfile  = path.join(mediaPath, 'build/output2.pcm')

console.log(rootPath)

local function mpp_perror(message, ret)
	print(message, string.format("0x%x", ret & 0xffffffff))
end

local audio_out = nil

local function getWavFileHeader(filelength, sampleRate, channels)
	local list = {}

	list[#list + 1] = "RIFF"
	list[#list + 1] = string.pack("<I4", filelength + 36)
	list[#list + 1] = "WAVE"

	local sampleBits = 16

	list[#list + 1] = "fmt "
	list[#list + 1] = string.pack("<I4", 16)
	list[#list + 1] = string.pack("<I2I2I4I4I2I2", 1, 2, sampleRate, channels, 4, sampleBits)


	list[#list + 1] = "data"
	list[#list + 1] = string.pack("<I4", filelength)

	return table.concat(list)
end

local function start_mpp()
	--console.log(lmedia)

	local version = lmedia.VERSION
	console.log('version', version)

	local ret = lmedia.init()
	if (ret ~= 0) then
        mpp_perror('init error', ret)
		return ret
	end

	local laudio_out = lmedia.audio_out
	console.log(laudio_out)

	audio_out = laudio_out.open(0, laudio_out.MEDIA_FORMAT_AAC)
	console.log(audio_out)

	local list = {}

	audio_out:start(function(packet, len, flags)
		local data = packet
		console.log(len, flags)
		list[#list + 1] = data
	end)

	local fileData = fs.readFileSync(filename)
	console.log("#fileData", #fileData)

	local start = 1
	local size = 1000
	local leftover = #fileData
	while (leftover > 0) do
		local packetSize = size
		if (packetSize > leftover) then
			packetSize = leftover
		end

		local data = fileData:sub(start, start + packetSize - 1)
		--console.printBuffer(data)

		audio_out:write(data)

		start = start + packetSize
		leftover = leftover - packetSize
	end

	console.log('list', #list)
	for _, v in ipairs(list) do
		console.printBuffer(v)
	end

	local data = table.concat(list)

	local header = getWavFileHeader(#data, 44100, 2)

	list = {}
	list[1] = header
	list[2] = data

	fs.writeFileSync(outfile, table.concat(list))

	fs.writeFileSync(pcmfile, data)

    return ret
end

local function stop_mpp()

end

local function main(args)

end

start_mpp()

main(arg)

setTimeout(100, function() end)

run_loop()
stop_mpp()

