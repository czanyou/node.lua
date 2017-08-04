local utils 	= require('utils')
local path 		= require('path')

local express 	= require('express')
local server   	= require('rtsp/server')
local session  	= require('media/session')
local camera    = require('media/camera')

local filename = 'mock:' .. path.join(utils.dirname(), "641.ts")
local mediaSession = session.startCameraSession(filename)

local exports = {}

local function getMockVideo()
    local dirname = utils.dirname()
    return path.join(dirname, "641.ts")
end

local function startCamera()
	print("start mock camera...")

	local cameraId   = camera.CAMERA_MOCK
    local mockImage  = utils.dirname()
    local mockVideo  = getMockVideo()

    local options   = {}
    options.basePath    = mockImage
    options.filename    = mockVideo
    options.bitrate     = 800
    options.width       = 640
    options.height      = 360
    options.frameRate   = 25

	return camera(cameraId, options)
end

local function getCamera(name)
    local cameraDevice = exports.camera
    if (not cameraDevice) then
        cameraDevice = startCamera(name)
        if (not cameraDevice) then
            return
        end

        exports.camera = cameraDevice
    end

    return cameraDevice   
end

function main()
	local cameraDevice = getCamera()
    if (not cameraDevice) then
        print(TAG, 'camera open failed!')
        return
    end

    local mediaSessionIdCounter = 1
    local mediaSessions = {}

    cameraDevice:setPreviewCallback(function(sample)
        for _, session in pairs(mediaSessions) do
        	session:writeSample(sample)
        end
    end)


	local count = 1

    -- cameraDevice:startPreview()

    local root = path.dirname(process.cwd())
	local app  = express({ root = root })

	app:get("/test.ts", function(request, response)
	  	response:set("Content-Type", "video/mp2t")
	    response:set("Transfer-Encoding", "chunked")

	    mediaSessionIdCounter = mediaSessionIdCounter + 1
	    local mediaSessionId = mediaSessionIdCounter
	    local mediaSession = session.newMediaSession()

	    mediaSession.mediaSessionId = mediaSessionId
	    mediaSessions[mediaSessionId] = mediaSession

	    function mediaSession:onSendSample(sample)
			if (not sample) then
				return
			end

			--console.log('sample', #sample)

			local list = {''}
			local sampleSize = 0
			for _, item in ipairs(sample) do
				sampleSize = sampleSize + #item

				list[#list + 1] = item
			end

			list[1] = string.format("%x\r\n", sampleSize)
			list[#list + 1] = "\r\n"

			local sampleData = table.concat(list)

			--console.log('sample', list[1], #sampleData, sampleSize)
			self:onSendPacket(sampleData)

			count = count + 1

			-- 流结束标识
		  	if (count > 20000) then
		  		self:onSendPacket("0\r\n\r\n")
		  		self:onSendPacket(nil)
		  		count = 1
		  	end
		end

	    local onPacket = function(packet)
	  		if (packet == nil) then
	  			mediaSession:readStop()
	  			mediaSession:close()
	  			response:finish()

	  			mediaSessions[mediaSession.mediaSessionId] = nil
	  			return
	  		end

	  		if (not response:write(packet)) then
	  			mediaSession:readStop()
	  		end
	  	end

	    response:on('drain', function()
	    	mediaSession:readStart(onPacket)
	    end)

	    response:on('close', function()
	    	mediaSession:readStop()
	    	mediaSession:close()
	    	mediaSessions[mediaSession.mediaSessionId] = nil
	    end)

	  	mediaSession:readStart(onPacket)
	end)

	app:listen(8000)
end

main()
