local path  	= require('path')
local utils		= require('utils')
local url   	= require('url')
local fs    	= require('fs')
local uv 		= require('uv')
local assert 	= require("assert")
local tap 		= require("ext/tap")

return tap(function(test)

test('test_m3u8', function()
	local list = [[
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:8
#EXT-X-MEDIA-SEQUENCE:2680

#EXTINF:7.975,
https://priv.example.com/fileSequence2680.ts 
#EXTINF:7.941,
https://priv.example.com/fileSequence2681.ts
#EXTINF:7.975,
https://priv.example.com/fileSequence2682.ts
]]

	local list2 = [[
#EXTM3U
#EXT-X-VERSION: 3
#EXT-X-TARGETDURATION: 8
#EXT-X-MEDIA-SEQUENCE: 2680

#EXTINF: 7.975,
https://priv.example.com/fileSequence2680.ts 
#EXTINF: 7.941,
https://priv.example.com/fileSequence2681.ts
#EXTINF: 7.975,
https://priv.example.com/fileSequence2682.ts
]]

	local m3u8 = require('hls/m3u8')

	local playList = m3u8.parse(list)
	--console.log(playList.playItems)

	local playList = m3u8.parse(list2)
	-- console.log(playList.playItems)
	--console.log(ret)
	assert.equal(3, #playList.playItems)

	assert.equal('3',    playList:get('EXT-X-VERSION'))
	assert.equal('2680', playList:get('EXT-X-MEDIA-SEQUENCE'))
	assert.equal('8',    playList:get('EXT-X-TARGETDURATION'))

	local playItem = playList.playItems[1]
	assert.equal('7.975', playItem.duration)
	assert.equal('https://priv.example.com/fileSequence2680.ts', playItem.path)

	--console.log(playList:toString())

	local playList3 = m3u8.parse(playList:toString())

	assert.equal('3',    playList3:get('EXT-X-VERSION'))
	assert.equal('2680', playList3:get('EXT-X-MEDIA-SEQUENCE'))
	assert.equal('8',    playList3:get('EXT-X-TARGETDURATION'))

	local playItem = playList3.playItems[1]
	assert.equal('7.975', playItem.duration)
	assert.equal('https://priv.example.com/fileSequence2680.ts', playItem.path)	
end)

test('test_master_list', function()
local list = [[
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1280000
low/audio-video.m3u8
#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=86000,URI="low/iframe.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=2560000
mid/audio-video.m3u8
#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=150000,URI="mid/iframe.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=7680000
hi/audio-video.m3u8
#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=550000,URI="hi/iframe.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=65000,CODECS="mp4a.40.5"
audio-only.m3u8
]]

	local m3u8 = require('hls/m3u8')

	local playList = m3u8.parse(list)
	--console.log(playList.headers)
	--console.log(playList.data)
	--console.log(playList.streams)

end)

test('test_string', function()
	local text = "/live/m3"
	assert.ok(text:startsWith('/live'))
	assert.ok(text:startsWith('/'))	
	assert.ok(text:startsWith('/live/m3'))
	assert.ok(not text:startsWith('/live/m32'))
	assert.ok(not text:startsWith('live'))

	assert.ok(not text:endsWith('/live'))
	assert.ok(not text:endsWith('/'))	
	assert.ok(text:endsWith('/live/m3'))
	assert.ok(not text:endsWith('/live/m32'))
	assert.ok(text:endsWith('/m3'))
end)

test('playList:addItem ', function()
	local m3u8 = require('hls/m3u8')

	local playList = m3u8.newList()
	playList:on('remove', function(item) 
		console.log('remove', item)
	end)

	playList:setTargetDuration(8)
	playList:setMediaSequence(10)
	playList:setEndList(false)

	playList:addItem('s1.ts', 10.1)
	playList:addItem('s2.ts', 8.5)
	playList:addItem('s3.ts', 7.2)
	playList:addItem('s4.ts', 6.3)

	print(playList:toString())
end)

test('playList:addItem with END-LIST', function()
	local m3u8 = require('hls/m3u8')

	local playList = m3u8.newList()

	playList:on('item', function(item) 
		console.log('item', item)
	end)

	playList:setTargetDuration(8)
	playList:setMediaSequence(10)
	playList:setEndList(true)

	playList:addItem('s1.ts', 10.1)
	playList:addItem('s2.ts', 8.5)
	playList:addItem('s3.ts', 7.2)
	playList:addItem('s4.ts', 6.3)

	print(playList:toString())
end)

end)
