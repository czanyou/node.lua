local utils   	= require('utils')
local lmedia  	= require('lmedia')
local thread  	= require('thread')
local uv      	= require('uv')
local fs      	= require('fs')

local audio_input 	= nil
local laudioin 		= lmedia.audio_in
local sampleRate 	= 8000
local channels   	= 2

local function mpp_perror(message, ret)
	print(message, string.format("0x%x", ret & 0xffffffff))
end

local function write_file(format, filedata)

	local list = {}
	if (format == laudioin.MEDIA_FORMAT_PCM) then
		local filename = "/tmp/record.wav"

		list[#list + 1] = "RIFF"
		list[#list + 1] = string.pack("<I4", #filedata + 36)
		list[#list + 1] = "WAVE"


		list[#list + 1] = "fmt "
		list[#list + 1] = string.pack("<I4", 16)
		list[#list + 1] = string.pack("<I2I2I4I4I2I2", 1, channels, sampleRate, 1000, 4, 16)


		list[#list + 1] = "data"
		list[#list + 1] = string.pack("<I4", #filedata)
		list[#list + 1] = filedata
		fs.writeFileSync(filename, table.concat(list))

		console.log(filename, #filedata)
	
	elseif (format == laudioin.MEDIA_FORMAT_AAC) then
		local filename = "/tmp/record.aac"
		fs.writeFileSync(filename, filedata)

	else
		local filename = "/tmp/record.ts"
		fs.writeFileSync(filename, filedata)
	end
end

local function start_mpp()
	--console.log(lmedia)
	local version = lmedia.VERSION
	console.log('version', version)

	--console.log(laudioin)

	lmedia.init()

	laudioin.init()

	local list = {}

	local format = laudioin.MEDIA_FORMAT_AAC
	format = laudioin.MEDIA_FORMAT_PCM

	local settings = {}
	settings.codec 		= format
	settings.sampleRate = sampleRate
	settings.channels   = channels

	local audio_in, err = laudioin.open(0, settings)
	console.log(audio_in, err) --, string.format("0x%x", err))
	if (audio_in == nil) then
		return
	end

	local maxFrames = 80

	audio_in:start(function(ret, sampleData, sampleTime, flags)

		if (#list < maxFrames + 1) then
			list[#list + 1] = sampleData:sub(8, #sampleData - 7)
		end

		console.log(#list, sampleTime, flags);

		if (#list == maxFrames) then
			audio_in:stop()
			audio_in:close()

			write_file(format, table.concat(list))
		end
	end)

    return ret
end

local function stop_mpp()

end

local function main(args)
    local channel = 0;

end

start_mpp()

main(arg)

setTimeout(100, function() end)

run_loop()
stop_mpp()

