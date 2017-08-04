local player    = require("app/player")
local lmessage 	= require('lmessage')
local fs        = require('fs')
local app       = require('app')
--console.log(player)

local handler

local function open(url, callback)
	return player.open(url, callback)
end

local function close(handler)
	return player.close(handler)
end

local function control(handler, ...)
	return player.control(handler, ...)
end

local filename = "test.264"
local stream = fs.createWriteStream(filename)

local cols = { 12, 6, 12, 12, 16, 16 }

local function onState( handler, event, data, param1, param2 )

	if (event == 'sample') then
		if (stream) then
       	 	stream:write(data)
       	end

       	if (param2 == 1) then
       		app.tableLine(cols, 'onState', handler, event, '...', param1, param2)
       	end

    elseif (event == 'describe') then

    else
		app.tableLine(cols, 'onState', handler, event, data, param1, param2)
    end
end

local mainQueue
mainQueue = lmessage.new_queue('main', 100, function(...)
    onState(...)
end)

local url = 'rtsp://locahost/test.mp4'
--local url = 'rtsp://127.0.0.1:554/a.ts'
--local url = 'rtsp://127.0.0.1:554/a2.ts'
--local url = 'rtsp://127.0.0.1:554/bb.mp4'
local url = "rtsp://218.204.223.237:554/live/1/67A7572844E51A64/f68g2mj7wjua3la7.sdp"
local url = "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov"
local url = 'rtsp://127.0.0.1:554/test.264'
local url = 'rtsp://127.0.0.1:554/641.ts'

handler = open(url, onState)

setTimeout(1000, function()
	control(handler, 100, "ABC")
end)

setTimeout(150 * 1000, function()
	close(handler)
	mainQueue:close()
end)

