local init  = require('init')
local utils = require('utils')

local source = require('media/source')

function test_media_source1()
	local options = {}
	local mediaSource = source.newMediaSource(options)

	mediaSource:newMediaSession()

	local mediaSession1 = mediaSource:newMediaSession()
	local mediaSession2 = mediaSource:newMediaSession()

	mediaSource:newMediaSession()
	mediaSource:newMediaSession()

	assert(#mediaSource.mediaSessions == 5)
	--console.log(mediaSource)

	mediaSource:removeMediaSession(mediaSession1)
	mediaSource:removeMediaSession(mediaSession2)

	assert(#mediaSource.mediaSessions == 3)
	--console.log(mediaSource)

	mediaSource:close()
	assert(#mediaSource.mediaSessions == 0)
end

function test_media_source2()
	local options = {}
	local mediaSource = source.newMediaSource(options)
	local mediaSession = mediaSource:newMediaSession()

	local sampleCount = 0

	mediaSession:readStart(function(sample) 
		console.log('sample', sample)

		sampleCount = sampleCount + 1

		assert(sampleCount <= 1)
	end)

	mediaSource:writeSample('000123456789', 9000, 0x01)
	mediaSource:writeSample('000123456789', 9000, 0x02)

	mediaSession:readStop()

	mediaSource:writeSample('000123456789', 9000, 0x01)
	mediaSource:writeSample('000123456789', 9000, 0x02)

	assert(#mediaSource.mediaSessions == 1)

	mediaSession:close()
	mediaSource:writeSample('000123456789', 9000, 0x01)
	mediaSource:writeSample('000123456789', 9000, 0x02)

	assert(#mediaSource.mediaSessions == 0)
	--console.log(mediaSource)
end


test_media_source1()
test_media_source2()

run_loop()
