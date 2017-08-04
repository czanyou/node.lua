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
local lmedia 	= require('lmedia')

local basePath = utils.dirname()
console.log(basePath)

function test_ts_writer()
	local hls = require('hls/writer')
	local StreamWriter = hls.StreamWriter

	local writer = StreamWriter:new()

	--console.log(writer)
	writer:start(function(packet, meta)
		--console.log('packet', #packet, meta)
	end)

	local list = {}
	for i = 1, 100 do
		list[#list + 1] = "abcdefghijklmn1234567890"
	end
	local data = table.concat(list)

	writer:writeSyncInfo(40)

	local startTime = uv.hrtime()
	for i = 1, 20000 do
		writer:write(data, 80)
	end
	local endTime = uv.hrtime()
	print((endTime - startTime) / 1000000)

	--writer:_writePAT()
	--writer:_writePMT()
	writer:close()
end

test_ts_writer()
