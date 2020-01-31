local assert 	= require('assert')
local tap 		= require('ext/tap')

local rtp 		= require('rtsp/rtp')

local test = tap.test

test("test rtp", function()
	local session = rtp.RtpSession:new()

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

	session.payload = 96
	session.rtpSsrc = 0x12345678
	local ret = session:encode(data, 102453)
	--console.log(ret, #ret)

	for i = 1, #ret do
		local packet = table.concat(ret[i])
		local ret = session:decode(packet)
		--console.log(ret)
	end
end)


test("test rtp nalu", function()

	local session = rtp.newSession()
	assert(session)

	assert(session:getNaluStartLength()  == 0)
	assert(session:getNaluStartLength(1) == 0)
	assert(session:getNaluStartLength("0001") == 0)

	assert(session:getNaluStartLength(string.char(0, 1, 0, 0)) == 0)
	assert(session:getNaluStartLength(string.char(0, 1, 0, 0)) == 0)
	assert(session:getNaluStartLength(string.char(0, 0, 1, 0)) == 3)
	assert(session:getNaluStartLength(string.char(0, 0, 0, 1)) == 4)
	assert(session:getNaluStartLength(string.char(0, 0, 0, 1, 1)) == 4)
	assert(session:getNaluStartLength(string.char(0, 0, 0, 0, 1)) == 0)

end)

test("test rtp encode header", function()

	local session = rtp.newSession()

	session.payload  = 21
	session.sequence = 512

	local packet = session:encodeHeader(80000, true) .. 
		string.char(0, 0, 1, 2, 3, 4, 5, 6)
	assert(packet)

	console.log(console.printBuffer(packet))

	local data = session:decodeHeader(packet, 1)
	assert.equal(data.marker,   true)
	assert.equal(data.payload,  21)
	assert.equal(data.rtpTime,  80000 * 90)
	assert.equal(data.sequence, 512)

end)

tap.run()
