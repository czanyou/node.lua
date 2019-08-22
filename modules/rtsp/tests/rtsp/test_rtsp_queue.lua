local utils = require('util')
local url 	= require('url')
local fs 	= require('fs')

local queue = require('media/queue')

return require('ext/tap')(function (test)

test('test_rtsp_queue', function()

	local rtspQueue = queue.newMediaQueue()

	rtspQueue:push("1234567890", 100, 0x00)
	assert(rtspQueue.waitSync == true)

	rtspQueue:push("1234567890", 100, 0x01)
	assert(rtspQueue.waitSync == false)
	--console.log(rtspQueue)

	rtspQueue:push("1234567890", 100, 0x00)
	--console.log(rtspQueue)

	rtspQueue:push("1234567890", 100, 0x02)
	assert(rtspQueue.currentSample == nil)

	local sample = rtspQueue:pop()

	--sample[1] = '1'

	assert(sample.isSyncPoint == true)
	assert(sample.sampleTime  == 100)
	assert(#sample >= 1)
	assert(#sample[1] > 3)
	--console.log(rtspQueue)

end)

test('test_rtsp_queue1', function()

	local data = "dsfjasdfklsdjfklsjgskdfjlaskjf;lksjdflksjadfkl"
	
	local buffer = {}
	local count = 100 * 100
	for i = 1, 100 do
		local packet = data .. i

		table.insert(buffer, packet)
	end

	for i = 1, count do
		local packet = data .. i

		table.insert(buffer, packet)
		table.remove(buffer, 1)
	end

end)

local function test_rtsp_queue2()

	local data = "dsfjasdfklsdjfklsjgskdfjlaskjf;lksjdflksjadfkl"

	local size = 1000

	print("start")
	local buffer = {}
	local count = 100 * 10000
	for i = 1, 100 do
		local packet = data .. i
		local pos = i % size
		buffer[pos] = packet
	end

	for i = 100, count do
		local packet = data .. i
		local pos = i % size

		buffer[pos] = packet

		local ret = type(packet)
		if (ret == 'string') then
			local pos = (i - 100) % size
			buffer[pos] = nil
		end
	end

	print("end")
end



end)

