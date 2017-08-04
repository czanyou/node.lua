#!/usr/bin/env lnode

local path 	 	= require('path')
local thread 	= require('thread')
local process 	= require('process')
local http 		= require('express')
local conf  	= require('ext/conf')
local utils 	= require('utils')
local fs 	 	= require('fs')
local uv 	 	= require('uv')

-- 如果提示找不到 lmedia.so, 请检查 lmedia.so 放置目录是否正确
local lmedia = require('lmedia') -- 加载 media.lua 库 (lmedia.so)

local interval 	= 100

-- ////////////////////////////////////////////////////////////////////////////
-- MPP

local lastImage = nil

local function on_media_stream(sample, sampleTime, size)
	print(sampleTime, size)
	lastImage = sample
end

local camera 	= require('media/camera')
local mock 		= nil

local function start_mpp()
	mock = camera.open(1)

	mock:setPreviewCallback(function(sample)
		
		on_media_stream(sample.sampleData, sample.sampleTime)
	end)

	mock:startPreview()
end

local Server = http.Server

local cache = {}

local function onImageRequest(filename, request, response)
	local fullname = path.join(process.cwd(), filename)
	
	function onImageData(err, data) 
		if (err) or (not data) then
			response:writeHead(404, {})
			response:finish()
			return
		end

		--print('fullname', #data)

		response:writeHead(200, {
			["Content-Type"] = 'image/jpeg',
		})
		response:write(data)
		response:finish()
	end

	if (lastImage) then
		onImageData(nil, lastImage)
	else
		onImageData(nil, nil)
	end
end

function Server:onRequest(request, response)
	--utils.console.log(request.uri)

	local pathname = request.uri.pathname
	--print('pathname', pathname)

	if (pathname == '/favicon.ico') then
		response:writeHead(404, {})
		response:finish()
		return true

	elseif (pathname == '/test.jpg') then	
		onImageRequest(pathname, request, response);
		return true

	elseif (pathname == '/live.jpg') then	
		onImageRequest(pathname, request, response);
		return true		
	end
end

function http_loop()
	local cwd = process.cwd()
	conf.search_path = cwd

	local root = path.join(process.cwd(), "")

	local server = Server:new()
	server.root = root;
	server:listen(8098)
	run_loop()
end

function main()
	local isRunning = true
	while (isRunning) do
		local _, err = pcall(http_loop)
		if (err) then
			print(err)
		end

		interval = math.min(1000 * 60, interval * 2)
		thread.sleep(interval)
		isRunning = true -- debug only
	end
end

start_mpp()
http_loop()

