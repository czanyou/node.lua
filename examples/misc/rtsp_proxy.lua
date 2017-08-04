local utils = require('utils')
local timer = require('timer')

local proxy  = require('rtsp/proxy')
local server = require('rtsp/server')

local rtspProxy = nil
local timeout = 350100

local startTime = os.uptime()

local function start_rtsp_proxy()
	local listPort = 9552

	print('Start RTSP proxy listen at ('.. listPort .. ') ...')
	rtspProxy = proxy.startServer(listPort)

	-- timeout
	if (timeout) then
		local function intervalTimer()
			local now = os.uptime()
			local span =  math.floor(startTime +timeout / 1000 - now)
			print("The server will exit after: " .. span .. ' seconds.')
		end

		intervalTimer()
		local intervalTimer = setInterval(5000, intervalTimer)

		timer.setTimeout(timeout, function ()
		  	print('RTSP Proxy', "timeout!", timeout)
		  	rtspProxy:close()
		end)
	end
end

function start_rtsp_server()
	local listPort = 9554

	print('Start RTSP server at ('.. listPort .. ') ...')
	local rtspServer = server.startServer(listPort, function(connection, pathname) 
		return rtspProxy:newMediaSession(pathname)
	end)

	-- set timeout
	if (timeout) then
		timer.setTimeout(timeout + 1000, function ()
		  	print("RTSP server", "timeout!", timeout)
		  	rtspServer:close()
		end)
	end
end

start_rtsp_proxy()
start_rtsp_server()
