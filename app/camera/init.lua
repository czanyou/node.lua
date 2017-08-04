local app       = require('app')
local conf      = require('ext/conf')
local fs        = require('fs')
local json      = require('json')
local path      = require('path')
local utils     = require('utils')

local media_manager = require('./media_manager')

local HTTP_PORT = 8001
local RTSP_PORT = 554

local exports = {}

-------------------------------------------------------------------------------
-- MediaSession

local function _startHttpServer(name, port)
    local express = require('express')

    media_manager.init(name)

    local app  = express({ root = nil })

    app:on('error', function(err)
        console.log('http', err)
        process:exit()
    end)

    app:get("/live.jpg", function(request, response)
        media_manager.snapshot(function(sample)
            if (not sample) then
                response:sendStatus(404)
                return
            end

            response:send(sample.sampleData, "image/jpeg")
        end)
    end)

    app:get("/live.ts", function(request, response)
        response:set("Content-Type", "video/mp2t")
        response:set("Transfer-Encoding", "chunked")

        local address = request.socket:address() or {}
        console.log('request', address.ip, address.port)
        request.socket:setTimeout(0)

        console.log('request.params', request.query)

        local params = request.query or {}
        local channel = params.stream or name or "1"

        local mediaSession = media_manager.getMediaSession(channel)
        --console.log(mediaSession)

        -- 重载 onSendSample 方法, 直接发送 TS 流到网络
        mediaSession.onSendSample = function(self, sample)
            if (not sample) then
                return
            end

            --if (sample.isAudio) then print('isAudio', sample.isAudio) end
            self:onSendPacket(table.concat(sample))
        end

        local onPacket = function(packet)
            if (packet == nil) then
                response:finish() -- end of stream

                media_manager.stopMediaSession(mediaSession)
                return
            end

            if (not response:write(packet)) then
                mediaSession:readStop()
            end
        end

        response:on('drain', function()
            mediaSession:readStart(onPacket)
        end)

        response:on('close', function()
            media_manager.stopMediaSession(mediaSession)
        end)

        mediaSession:readStart(onPacket)
    end)

    app:on('error', function(err)
        console.log('HTTP error: ', err)
    end)

    port = port or 8001
    app:listen(port)

    print('  use http://localhost:'.. port .. '/live.ts to view video streaming.')
end

-- 开始录像, 将采集到的视频流直接录制成文件
local function _startRecording(name, filename, timeout)
    timeout = tonumber(timeout) or 10

    if (not filename) then
        local time = os.date("%Y%m%dT%H%M%S")
        filename = '/tmp/s' .. time .. '.ts'
    end
    print("Save to: " .. filename)

    local options = { filename = filename }
    local recorder = recorder.openRecorder(options)

    -- camera
    local cameraDevice = media_manager.getCamera(name)
    cameraDevice:setPreviewCallback(function(sample)
        if (not recorder) then
            cameraDevice:stopPreview()
            return
        end

        recorder:write(sample)
    end)

    -- stat & timeout
    local timerId
    timerId = setInterval(1000, function()
        print('total bytes: ' .. tostring(recorder.totalBytes))
    end)

    setTimeout(timeout * 1000, function()
        clearInterval(timerId)

        if (recorder) then
            recorder:close()
            recorder = nil

            print("finish!")
        end
    end)

    cameraDevice:startPreview()
end

local function _startRtspServer(name, port)
    local server = require('rtsp/server')

    media_manager.init(name)

    local listenPort = tonumber(port) or RTSP_PORT
    print('RTSP server listening at ('.. listenPort .. ') ...')
    print('  use rtsp://localhost:'.. listenPort .. '/live.mp4 to view video streaming.')

    local rtspServer = server(listenPort, function(connection, path) 
        print('connection', path)

        return media_manager.getMediaSession(name)
    end)

    rtspServer:on('error', function(err)
        print('RTSP', 'error', err)

        rtspServer:close()
    end)
end

local function _startTakePicture(cameraDevice, interval, callback)
    local takePicture = function(interval)
        cameraDevice:takePicture(function(sample)
            if (sample and callback) then
                callback(sample.sampleData)
            end
        end)
    end

    local takeTimer = nil

    interval = tonumber(interval) or -1
    if (interval > 0) then
        takeTimer = setInterval(interval * 1000, function()
            takePicture(interval)
        end)

        takePicture(interval)
        print("Snapshot interval: " .. interval .. ' S.')

    else
        local model = cameraDevice.model
        local timeout = 4000
        if (model == 'uvc') then
            timeout = 100

        elseif (model == 'nanopi') then
            timeout = 100            
        end

        -- 等待 Camera 完全启动后再抓拍, hi3516a 要 5 秒左右, 否则黑屏
        setTimeout(timeout, function()
            takePicture(interval)
        end)
    end
end

-------------------------------------------------------------------------------
-- exports

function exports.help()
    app.usage(utils.dirname())

    print([[
Supported camera: 

- Linux UVC (USB camera)
- Hi35xx camera
- Mock camera

Available command:

- help      Display help information
- http      Start camera with HLS server
- record    Start camera with recording
- rtsp      Start camera with RTSP server
- snapshot  Start camera with snapshot
- start     Start camera with RTSP/snapshot ...
- list      Show all available cameras

]])
end

function exports.http(name, port)
    if (not name) then
        print([[

usage: lpm camera http [name] [port]

Start HTTP live streaming...

- name:       camera ID, 'mock' or '1'
- timeout:    in seconds

]])

    end

    _startHttpServer(name, port)
end

function exports.list()
    media_manager.list()
end

-- 测试录像功能
function exports.record(name, filename, timeout)
    if (not name) then
        print([[

usage: lpm camera record [name] [filename] [timeout]

Start camera with video recording...
    
- name:       camera ID, 'mock' or '1'
- filename:   output filename
- timeout:    record duration in seconds

]])
    end

    _startRecording(name, filename, timeout)
end

-- 测试 RTSP 服务
function exports.rtsp(name, port)
    if (not name) then
        print([[

usage: lpm camera rtsp [name] [port]

Start camera preview with RTSP streaming server.
    
- name:       camera ID, 'mock' or '1'
- port:       1~65535, RTSP port, default is 554

]])
    end

    _startRtspServer(name, port)
end

-- 测试抓拍功能
function exports.snapshot(name, filename, interval)
    if (not name) then
        print([[

usage: lpm camera snapshot [name] [filename] [interval]

Take a picture and save to file...
    
- name:       camera ID, 'mock' or '1'
- filename:   output filename
- interval:   snapshot interval in seconds

]])
    end

    local cameraDevice = media_manager.getCamera(name)
    if (not cameraDevice) then
        print('Invalid camera name: ', name)
        return
    end

    local color = console.color
    if (not filename) then
        local time = os.date("%Y%m%d_%H%M%S")
        filename = 'snaphost_' .. time .. '.jpg'
    end

    print(color('string') .. 'Snapshoting...', color())
    _startTakePicture(cameraDevice, interval, function(data)
        if (not data) then
            return
        end

        print("Saved: " .. color('string') .. filename .. color('number') 
            .. ' (size:' .. #data .. ')', color())

        fs.writeFile(filename, data, function(err)
            if (err) then 
                console.log('writeFile', err) 
            end

            if (not interval) then
                setTimeout(100, media_manager.release)
            end
        end)
    end)
end

function exports.settings()
    local profile = conf('camera')
    print("Audio In Settings: audio.in = ")
    console.log(profile:get('audio.in') or {})

    print("Video In Settings: ")
    console.log(profile:get('video') or {})    
end

function exports.set(name, value)
    local profile = conf('camera')
    if (name) then
        profile:set(name, value)
        profile:commit()
    end

    exports.settings()
end

-- 
function exports.start(name, httpPort, rtspPort)
    local lockfd = app.tryLock('camera')
    if (not lockfd) then
        print('The camera is locked!')
        return
    end

    if (not name) then
        print([[

usage: lpm camera start [name] [port]

start camera with HTTP live streaming ..
    
- name:       camera ID, 'mock' or '1', default is auto
- port:       HTTP port, default is 8001

]])
    end

    --
    name = name or '1'

    _startHttpServer(name, httpPort)
    _startRtspServer(name, rtspPort)
end

app(exports)
