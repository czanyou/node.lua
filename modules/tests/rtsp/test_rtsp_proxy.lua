local init 	= require('init')
local utils = require('utils')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local core 	= require('core')
local timer = require('timer')

local proxy = require('rtsp/proxy')
local push  = require('rtsp/push')

local function test_rtsp_proxy()
	local rtspProxy = proxy.RtspProxy:new()

	local pathname = '/live/channel1'
	local session = rtspProxy:getProxySession(pathname, true)

	--console.log(session)

	local mediaSession = rtspProxy:newMediaSession(pathname)
	--console.log('test_rtsp_proxy', mediaSession)

	--console.log(rtspProxy)
	--assert(#rtspProxy.sessions == 1)

	rtspProxy:removeProxySession(session)

	pathname = '/live/channel2'
	local session = rtspProxy:getProxySession(pathname, true)
	session:close()

	rtspProxy:close()
end

test_rtsp_proxy()

run_loop()

