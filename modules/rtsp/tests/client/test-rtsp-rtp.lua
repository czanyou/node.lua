local assert 	= require('assert')
local tap 		= require('util/tap')
local rtp 		= require('rtsp/rtp')

describe("test rtp", function()
	rtp.RTP_MAX_SIZE = 16

	local data = [[
asfsdf
file:seek()string.format(sd
	file:setvbuf(file:setvbuf(file:read(

		asfsaf
		select(fdsaf
			asfd
			assert(v), )))))

string.format(file:seek()file:seek()

	file:seek()string.format(
		file:seek()string.format(

			asfsf
			)))
string.format(
	string.format(asfd
		asfasf
		))
	]]

	local rtpSession = rtp.RtpSession:new()
	rtpSession.payload = 96
	rtpSession.rtpSsrc = 0x12345678
	local ret = rtpSession:encode(data, 102453)
	--console.log(ret, #ret)

	for i = 1, #ret do
		local packet = table.concat(ret[i])
		local ret = rtpSession:decode(packet)
		--console.log(ret)
	end
end)

describe("test rtp - nalu", function()
	local rtpSession = rtp.newSession()
	assert(rtpSession)

	assert(rtpSession:getNaluStartLength()  == 0)
	assert(rtpSession:getNaluStartLength(1) == 0)
	assert(rtpSession:getNaluStartLength("0001") == 0)

	assert(rtpSession:getNaluStartLength(string.char(0, 1, 0, 0)) == 0)
	assert(rtpSession:getNaluStartLength(string.char(0, 1, 0, 0)) == 0)
	assert(rtpSession:getNaluStartLength(string.char(0, 0, 1, 0)) == 3)
	assert(rtpSession:getNaluStartLength(string.char(0, 0, 0, 1)) == 4)
	assert(rtpSession:getNaluStartLength(string.char(0, 0, 0, 1, 1)) == 4)
	assert(rtpSession:getNaluStartLength(string.char(0, 0, 0, 0, 1)) == 0)

end)

describe("test rtp - encode header", function()
	local rtpSession = rtp.newSession()
	rtpSession.payload  = 21
	rtpSession.sequence = 512

	-- encodeHeader
	local data = string.char(0, 0, 1, 2, 3, 4, 5, 6)
	local packet = rtpSession:encodeHeader(80000, true) .. data
	assert(packet)

	console.log(console.printBuffer(packet))

	-- decodeHeader
	local header = rtpSession:decodeHeader(packet, 1)
	assert(header)
	assert.equal(header.marker,   true)
	assert.equal(header.payload,  21)
	assert.equal(header.rtpTime,  80000 * 90)
	assert.equal(header.sequence, 512)

end)
