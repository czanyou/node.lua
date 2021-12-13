local net = require('net')
local util = require('util')
local rtmp = require("rtmp")
local core  = require('core')
local url = require('url')

local queue = require('rtmp/queue')

local exports = {}
local null = rtmp.amf0.null
local flv = rtmp.flv

local RTMP_PORT = 1935;
local RTMP_CHUNK_SIZE = 128;

exports.RTMP_PORT = RTMP_PORT;

-- RTMP message type
local MESSAGE = rtmp.MESSAGE

local RTMP_HANDSHAKE_SIZE = 1536;
local RTMP_HANDSHAKE_UNINIT = 0;
local RTMP_HANDSHAKE_0 = 1;
local RTMP_HANDSHAKE_1 = 2;
local RTMP_HANDSHAKE_2 = 3;

local RTMP_CHUNK_TYPE_0 = 0; -- 11-bytes: timestamp(3) + length(3) + stream type(1) + stream id(4)
local RTMP_CHUNK_TYPE_1 = 1; -- 7-bytes: delta(3) + length(3) + stream type(1)
local RTMP_CHUNK_TYPE_2 = 2; -- 3-bytes: delta(3)
local RTMP_CHUNK_TYPE_3 = 3; -- 0-byte

exports.STATE_STOPPED = 0;
exports.STATE_INIT = 1;
exports.STATE_HANDSHAKE = 2;
exports.STATE_CONNECTED = 5;
exports.STATE_CREATE_STREAM = 6;
exports.STATE_PUBLISHING = 8;
exports.STATE_PLAYING = 9;

---@class RTMPClient
local RTMPClient = core.Emitter:extend()
exports.RTMPClient = RTMPClient

-- @events
-- close, error, connect, audio, video, metadata, command, state, startStreaming, request, response

---@param options any
function RTMPClient:initialize(options)
    self.appName = nil -- RTMP application name 'live'
    self.connected = false -- Socket connected
    self.connectTimer = nil -- Socket connect timer
    self.isPublish = true -- is PUBLISH mode
    self.isStartStreaming = false -- is startStreaming
    self.lastActiveTime = process.now()
    self.mediaQueue = queue.newMediaQueue() -- media stream queue
    self.options = options or {} -- options
    self.socket = nil -- Socket
    self.state = exports.STATE_STOPPED -- RTMP state
    self.streamId = 0 -- RTMP stream ID
    self.streamName = nil -- RTMP stream name
    self.urlObject = nil -- RTMP URL object
    self.urlString = nil -- RTMP URL string

    self.audioSamples = 0 -- sent audio sample count
    self.chunkSize = nil
    self.localChunkSize = RTMP_CHUNK_SIZE -- local RTMP chunk size
    self.peerChunkSize = RTMP_CHUNK_SIZE -- peer RTMP chunk size
    self.startTime = nil -- startStreaming
    self.videoParameterSets = nil -- AVC Video parameter sets (pps/sps)
    self.isVideoConfigurationSent = false -- is parameter sets sent
    self.videoSamples = 0 -- sent video sample count
    self.windowAckSize = nil -- RTMP window ack size

    self.id = (exports.INSTANCE_ID_COUNTER or 0) + 1 -- ID
    exports.INSTANCE_ID_COUNTER = self.id

    self.lastData = nil
    self.isNotDrain = nil
    self.metadata = nil
end

-- 关闭这个客户端
function RTMPClient:close(error)
    if (self.socket) then
        self.socket:close()
        self.socket = nil
        self:emit('close')
    end

    if (error) then
        self:emit('error', error)
    end

    self.connected = false
    self.isPublish = true
    self.isStartStreaming = false
    self.lastData = nil
    self.sentC2 = nil

    self.audioSamples = 0
    self.localChunkSize = RTMP_CHUNK_SIZE
    self.peerChunkSize = RTMP_CHUNK_SIZE
    self.startTime = nil
    self.isVideoConfigurationSent = false
    self.videoSamples = 0
    self.windowAckSize = nil

    self:setState(exports.STATE_STOPPED)

    if (self.timer) then
        clearInterval(self.timer)
        self.timer = nil
    end

    if (self.connectTimer) then
        clearTimeout(self.connectTimer)
        self.connectTimer = nil
    end
end

-- 创建 RTMP 连接
---@param urlString string
function RTMPClient:connect(urlString)
    if (self.socket) then
        return
    end

    if (not urlString) then
        return self:close('Empty URL String')
    end

    -- url
    local urlObject = url.parse(urlString) or {}
    self.urlString = urlString
    self.urlObject = urlObject

    local host = urlObject.host
    local port = urlObject.port or RTMP_PORT
    local pathname = urlObject.pathname or ''
    local tokens = pathname:split('/')

    self.appName = tokens[2] or 'live'
    self.streamName = tokens[3] or ''

    if (not host) then
        return self:close('Empty RTMP server host name')

    elseif (not self.appName) then
        return self:close('Empty RTMP server app name')

    elseif (not self.streamName) then
        return self:close('Empty RTMP server stream name')
    end

    -- socket
    local socket = net.Socket:new()
    local rtmpClient = self

    -- 当收到 Socket 数据包
    local onData = function(data)
        -- console.log('socket:on("data")', #data)

        local chunkData = nil
        if (self.lastData) then
            chunkData = self.lastData .. data
        else
            chunkData = data
        end

        -- console.log('chunkData.length', #chunkData)

        local index = 1;
        while (true) do
            if (index > #chunkData) then
                break
            end

            -- Handshake
            if (self.state == exports.STATE_INIT) then
                if (#chunkData < 1537) then
                    break
                end

                -- S0 + S1
                if (not self.sentC2) then
                    local version, time, zero = string.unpack(">BI4I4", chunkData, index)
                    -- console.log(version, time, zero)

                    self:sendC2(time)
                    self.sentC2 = true
                end

                if (#chunkData < 3073) then
                    break
                end

                -- S0 + S1 + S2
                index = 3073 + 1
                self:setState(exports.STATE_HANDSHAKE)

            else
                local header, body, raw = rtmp.parseChunk(chunkData, index)
                if (header == nil) then
                    break
                end

                rtmpClient:processMessage(header, body, raw)
                index = index + header.headerSize + header.messageLength
            end
        end

        -- 保存剩余的数据
        self.lastData = nil
        if (index <= #chunkData) then
            if (index > 1) then
                self.lastData = chunkData:sub(index, #chunkData)
            else
                self.lastData = chunkData
            end
        end
    end

    -- 已建立 Socket 连接
    local onSocketConnect = function()
        self.connected = true
        self:emit('connect')
        self:setState(exports.STATE_INIT)

        socket:on("data", onData)
    end

    -- 发生网络错误
    local onSocketError = function(error)
        self:close(error)
        self.lastError = error
    end

    -- 发送缓存区已空
    local onSocketDrain = function()
        self.isNotDrain = false
        self:flushVideoStream()
    end

    -- Socket 被关闭
    local onSocketClose = function()
        self:close('socket.close')
    end

    -- 连接超时
    local onConnectTimeout = function()
        self:close('rtmp.connectTimeout')
    end

    socket:on("close", onSocketClose)
    socket:on("error", onSocketError)
    socket:on("drain", onSocketDrain)

    -- 开始创建 Socket 连接，并设置超时定时器
    socket:connect(port, host, onSocketConnect)

    local timeout = self.options.timeout or 5000
    self.connectTimer = setTimeout(timeout, onConnectTimeout)
    self.socket = socket
end

-- 内部方法
function RTMPClient:flushVideoStream()
    if (not self.isStartStreaming) then
        return -- 还没有开始推流

    elseif (self.isNotDrain) then
        return -- 之前的数据还在发送中
    end

    -- 发送下一帧数据
    local sample = self.mediaQueue:pop()
    if (sample) then
        self:sendVideoSample(sample[1], sample.sampleTime)
    end
end

function RTMPClient:getStatus()
    local status = {}
    status.appName = self.appName
    status.isPublish = self.isPublish
    status.lastActiveTime = self.lastActiveTime
    status.streamId = self.streamId
    status.streamName = self.streamName
    status.urlObject = self.urlObject

    status.connected = self.connected
    status.id = self.id
    status.isNotDrain = self.isNotDrain
    status.isStartStreaming = self.isStartStreaming
    status.lastError = self.lastError
    status.isVideoConfigurationSent = self.isVideoConfigurationSent

    status.audioSamples = self.audioSamples
    status.metadata = self.metadata
    status.peerChunkSize = self.peerChunkSize
    status.startTime = self.startTime
    status.videoSamples = self.videoSamples
    status.windowAckSize = self.windowAckSize
    return status
end

---@param state integer
---@return string
function RTMPClient:getStateString(state)
    if (state == exports.STATE_STOPPED) then
        return 'stopped'

    elseif (state == exports.STATE_INIT) then
        return 'init'

    elseif (state == exports.STATE_HANDSHAKE) then
        return 'handshake'

    elseif (state == exports.STATE_CONNECTED) then
        return 'connected'

    elseif (state == exports.STATE_CREATE_STREAM) then
        return 'create-stream'

    elseif (state == exports.STATE_PUBLISHING) then
        return 'publishing'

    elseif (state == exports.STATE_PLAYING) then
        return 'playing'

    else
        return 'unknown'
    end
end

-- 内部方法，处理收到的 RTMP 消息
---@param header any
---@param body any
---@param raw string
function RTMPClient:processMessage(header, body, raw)
    self:emit('response', header, body, raw)
    --console.log('processMessage: response', header.messageType, body)

    self.lastActiveTime = process.now()

    local messageType = header.messageType

    if (messageType == MESSAGE.DATA_MESSAGE) then
        --console.log('response', messageLength, #raw)
        self:emit('metadata', header, body, raw)

    elseif (messageType == MESSAGE.WINDOW_ACKNOWLEDGEMENT_SIZE) then
        self.windowAckSize = body
        self:sendSetWindowAckSize()

    elseif (messageType == MESSAGE.SET_PEER_BANDWIDTH) then
        -- self.peerBandWidth = body

    elseif (messageType == MESSAGE.SET_CHUNK_SIZE) then
        self.peerChunkSize = body

    elseif (messageType == MESSAGE.COMMAND_MESSAGE) then
        local name = body[1]
        local tid = body[2]

        self:emit('command', header, body, raw)

        if (name == '_result') then
            local result = body[4]

            if (self.state == exports.STATE_HANDSHAKE) then
                if (result and result.level == 'error') then
                    self:close(result)
                    return
                end

                --console.log('STATE_CONNECTED result', result)
                self:setState(exports.STATE_CONNECTED)

            elseif (self.state == exports.STATE_CONNECTED) then
                self.streamId = result
                self:setState(exports.STATE_CREATE_STREAM)

                --console.log('STATE_CREATE_STREAM result', result)

            elseif (self.state == exports.STATE_CREATE_STREAM) then
                if (result and result.level == 'error') then
                    self:close(result)
                    return
                end

                --console.log('STATE_PUBLISHING result', result)

                self:setState(exports.STATE_PUBLISHING)
            end

        elseif (name == 'onStatus') then
            -- 1. Command Name
            -- 2. Transaction ID
            -- 3. Command - always null
            -- 4. Info
            local result = body[4]
            if (not result) then
                return

            elseif (result.level == 'error') then
                self:close(result)
                return

            elseif (result.level == 'status') then
                if (self.isPublish)then
                    self:setState(exports.STATE_PUBLISHING)
                    self:startStreaming()

                else
                    self:setState(exports.STATE_PLAYING)
                end
            end
        end

    elseif (messageType == MESSAGE.AUDIO_MESSAGE) then -- audio
        --console.log('response', messageLength, #raw)
        self:emit('audio', header, body, raw)

    elseif (messageType == MESSAGE.VIDEO_MESSAGE) then -- video
        self:emit('video', header, body, raw)

    elseif (messageType == MESSAGE.USER_CONTROL_MESSAGE) then

    else
        --console.log('response', header, body)
    end
end

-- 发送握手请求
function RTMPClient:sendC0C1()
    local now = process.now() % 0xFFFFFFFF; -- limit to 32bit
    local header = string.pack(">BI4I4", 0x03, now, 0x00)

    local c0c1 = '249f942f5c3acbd1d355495627a42ca1bf0f7aa2a872e77bd7e052a47f74d18c226cac67907f476ac57ab1d62dcf86d5c70f7e7e7275ea515c43e6c4a8bf58b33a132ab37b5a2d48bdcf2ddba59cc07b9c4deb15abdc570f2f45c4c0ed2b832e2896d38cd90fbda6c7d3887c7e4fe82186da2840c66838de96e6a592182fb229b68ca7978c6b4c5a4ec5c7bd24b7d09398e1bc6550e652d8dbe171e41f3215c7a7ad653a27a2865e6e5c2b7b1ae41da4cccb182bc05412a2446d8d54909322474778725821e1a78145bbe550a612dd81c6df9e8d42993e6f15b4ac8f4fc0bf7f3f38c04a2977b45f39a898d1a385597873e8149e893b1c8fd9b9253780d59fa9156fe42fcf9f7717561ed1eb8c3a6af0297095a394a2427c63509ccc354b843ba36f53811dbb895dc2624f5e8daa55a721d45aa77d852ad1c6b0a5e4e4302696916a26972c98ddd8eb3b3d7fcf7b36e15e798fcdefaba5bc6a59a85d7bbfdc133111934692802d8da45b1382c03a732d9c11eb92a5a05e16e2155c64bd4768df41e52dc5744b591f905d935f81ef7d2ce970b09e1715a5e2131156c141afa874a3c6481e188a2f99d8abe160a9667ea1c73546c73bd5b83fcf1de91fb6a0846075b5707f4e881f2e3a107fd467e67c352ab4ed4e90ac7e6ebb777e781eecc985b040ede8b91b1de41485bf6c7b4b8a8ee886ce874253e6e6bb6b6dcb6645571e7753ef37571b235d91cbb2131d4c9314bb6884e6ac71d36fc64f413b7e8142debd401c23442869bfe523c311605d0f22b67c106adfd4c2b43312d89a842a8750538c5c81a6b74f9acb19943268943d25203e78e82249a33e448ac9b19d57eadacc566a8114a222c8aca0e31b432f324c5f933b6acecf99196169bcefa9b5d0841249ef17dc18c890a9ba9cd6d3bf29395a5694372c34397e86e67536ab54a3a687a1af6aab7eeb5b4897402a5d5b4ca8a2d1c8bfee114583e0aba292e854487edfe8da9175ccdda66a2db9b979146822ce38cacb321e5521b2e8a5aa4cde2f3acd10bc49cea0e147bea1e93ea759497c822357a52a9db7c68d6377c25097ed2c99b05f6e5f4f9e25d9975487e18f136a9b5b16aee1be837531eb466a8a428032dbd0914a263e60f0be9d87a6338b17b7cf1e75b7cee13ce8d473616d9fca8889a920bcc04723c0efb24ea4d6caad9da0b4196691e39380c616cb3aa6a4b3365dbce4241316d511b9329e97e5523b94163dec902f8618e78dd4283a7fc562c5904ddb8c54bf8615db3495c76fc16b6eef5ef02dd50f1b6ad4358d5aebd82f8234191e72c19578a3b21c7a29c6ce88bc3b7fda177fdf6a5a1be9a6efd0c680eed0876f9824d84bc7ddb6d9aa937175b7d95eb7684431b35021604eda35b8d7ee4e55966334ca32188f1ab3297437c95d7f87aeb4a970eeb3ba439de0ec83d642c27396e74cb9e9ccbdabde40d4b68e5a44431ddf9d12996647454d3ab2326d8396ed71d3ad69a6791c93abd95040428675486c214cee707c43aea7ded21c706f18ca52b63be137487cd328b51a5b4278949782d195e354c999edb67a102dd219e02bb82a1ce05b89ba7445beb879455c1fb134a59b7a75436e3aa66f50887140a43053a9209839c3137090bddabf20e27f459721a81b56253fe57d8074d7b12817eeba2095e5d49964746545427636aaa5b6bc5cc3196bebf0d17a6bb83384b83046c9ae3aa4568727a5b55222dcedb09ab11464bb705eb250c92d0fe59ab01cd188bb123c198a4caf4e90ba328472b5447728e9d877aa2f47c0283c62c9494259143e7e16b1bbaee952772ac8dac81b60e1133f67a758977671c4c94915138b12421819dcc5b8d41e36e7d718bee469aee0921c96dba5145b70c68d76c22871ed297bd9df3abce762b3cd6b80b8bd36a856434540d14284511821b0cb3231c84c95b033b97b292a35e77ea7a742ce5e8a188cbbd3c04f33c959cc9b7ce672b18329d54b8eef5eb4decd6a941e3fdb99417664233d9c3fefe61a9a69ea13297c26e8b0a5e61d68cbdbbc66e2e4488334a8d048d67b78d5687c76c26d7ad4d291cb913db99f978b815ae36a4d3ade73d3bda4b13f2c9598911a61ef7d45d0161f7044c116c45c802d4ed36471c1c84c857beeb6908a5d308da8'
    local message = header .. util.hex2bin(c0c1)
    -- console.log('sendC0C1', #message, now)
    self:sendData(message)
end

-- 发送握手请求
function RTMPClient:sendC2(time)
    time = time % 0xFFFFFFFF; -- limit to 32bit
    local header = string.pack(">I4I4", time, 0x00)
    local c2   = '249f942f5c3acbd1d355495627a42ca1bf0f7aa2a872e77bd7e052a47f74d18c226cac67907f476ac57ab1d62dcf86d5c70f7e7e7275ea515c43e6c4a8bf58b33a132ab37b5a2d48bdcf2ddba59cc07b9c4deb15abdc570f2f45c4c0ed2b832e2896d38cd90fbda6c7d3887c7e4fe82186da2840c66838de96e6a592182fb229b68ca7978c6b4c5a4ec5c7bd24b7d09398e1bc6550e652d8dbe171e41f3215c7a7ad653a27a2865e6e5c2b7b1ae41da4cccb182bc05412a2446d8d54909322474778725821e1a78145bbe550a612dd81c6df9e8d42993e6f15b4ac8f4fc0bf7f3f38c04a2977b45f39a898d1a385597873e8149e893b1c8fd9b9253780d59fa9156fe42fcf9f7717561ed1eb8c3a6af0297095a394a2427c63509ccc354b843ba36f53811dbb895dc2624f5e8daa55a721d45aa77d852ad1c6b0a5e4e4302696916a26972c98ddd8eb3b3d7fcf7b36e15e798fcdefaba5bc6a59a85d7bbfdc133111934692802d8da45b1382c03a732d9c11eb92a5a05e16e2155c64bd4768df41e52dc5744b591f905d935f81ef7d2ce970b09e1715a5e2131156c141afa874a3c6481e188a2f99d8abe160a9667ea1c73546c73bd5b83fcf1de91fb6a0846075b5707f4e881f2e3a107fd467e67c352ab4ed4e90ac7e6ebb777e781eecc985b040ede8b91b1de41485bf6c7b4b8a8ee886ce874253e6e6bb6b6dcb6645571e7753ef37571b235d91cbb2131d4c9314bb6884e6ac71d36fc64f413b7e8142debd401c23442869bfe523c311605d0f22b67c106adfd4c2b43312d89a842a8750538c5c81a6b74f9acb19943268943d25203e78e82249a33e448ac9b19d57eadacc566a8114a222c8aca0e31b432f324c5f933b6acecf99196169bcefa9b5d0841249ef17dc18c890a9ba9cd6d3bf29395a5694372c34397e86e67536ab54a3a687a1af6aab7eeb5b4897402a5d5b4ca8a2d1c8bfee114583e0aba292e854487edfe8da9175ccdda66a2db9b979146822ce38cacb321e5521b2e8a5aa4cde2f3acd10bc49cea0e147bea1e93ea759497c822357a52a9db7c68d6377c25097ed2c99b05f6e5f4f9e25d9975487e18f136a9b5b16aee1be837531eb466a8a428032dbd0914a263e60f0be9d87a6338b17b7cf1e75b7cee13ce8d473616d9fca8889a920bcc04723c0efb24ea4d6caad9da0b4196691e39380c616cb3aa6a4b3365dbce4241316d511b9329e97e5523b94163dec902f8618e78dd4283a7fc562c5904ddb8c54bf8615db3495c76fc16b6eef5ef02dd50f1b6ad4358d5aebd82f8234191e72c19578a3b21c7a29c6ce88bc3b7fda177fdf6a5a1be9a6efd0c680eed0876f9824d84bc7ddb6d9aa937175b7d95eb7684431b35021604eda35b8d7ee4e55966334ca32188f1ab3297437c95d7f87aeb4a970eeb3ba439de0ec83d642c27396e74cb9e9ccbdabde40d4b68e5a44431ddf9d12996647454d3ab2326d8396ed71d3ad69a6791c93abd95040428675486c214cee707c43aea7ded21c706f18ca52b63be137487cd328b51a5b4278949782d195e354c999edb67a102dd219e02bb82a1ce05b89ba7445beb879455c1fb134a59b7a75436e3aa66f50887140a43053a9209839c3137090bddabf20e27f459721a81b56253fe57d8074d7b12817eeba2095e5d49964746545427636aaa5b6bc5cc3196bebf0d17a6bb83384b83046c9ae3aa4568727a5b55222dcedb09ab11464bb705eb250c92d0fe59ab01cd188bb123c198a4caf4e90ba328472b5447728e9d877aa2f47c0283c62c9494259143e7e16b1bbaee952772ac8dac81b60e1133f67a758977671c4c94915138b12421819dcc5b8d41e36e7d718bee469aee0921c96dba5145b70c68d76c22871ed297bd9df3abce762b3cd6b80b8bd36a856434540d14284511821b0cb3231c84c95b033b97b292a35e77ea7a742ce5e8a188cbbd3c04f33c959cc9b7ce672b18329d54b8eef5eb4decd6a941e3fdb99417664233d9c3fefe61a9a69ea13297c26e8b0a5e61d68cbdbbc66e2e4488334a8d048d67b78d5687c76c26d7ad4d291cb913db99f978b815ae36a4d3ade73d3bda4b13f2c9598911a61ef7d45d0161f7044c116c45c802d4ed36471c1c84c857beeb6908a5d308da8'
    local message = header .. util.hex2bin(c2)
    -- console.log('sendC2', #message)
    self:sendData(message)
end

-- 发送 RTMP 连接请求，在握手成功后调用
function RTMPClient:sendConnect()
    -- 03 000000 0000f7 14 00000000 02 0007 636f6e6e656374 00 3ff0000000000000 03 0003 617070 02 0004 6c697665
    local connect = '030000000000f71400000000020007636f6e6e656374003ff00000000000000300036170700200046c6976650008666c61736856657202000e57494e2031352c302c302c323339000673776655726c0200000005746355726c02001c72746d703a2f2f696f742e626561636f6e6963652e636e2f6c6976650004667061640100000c6361706162696c697469'--c3657300406de00000000000000b617564696f436f646563730040abee0000000000000b766964656f436f6465637300406f800000000000000d766964656f46756e6374696f6e003ff000000000000000077061676555726c020000000e6f626a656374456e636f64696e67000000000000000000000009
    local message = util.hex2bin(connect)
    self:sendData(message)

    -- c3 fmt = 3
    connect = 'c3657300406de00000000000000b617564696f436f646563730040abee0000000000000b766964656f436f6465637300406f800000000000000d766964656f46756e6374696f6e003ff000000000000000077061676555726c020000000e6f626a656374456e636f64696e67000000000000000000000009'
    message = util.hex2bin(connect)
    self:sendData(message)
end

function RTMPClient:sendSetWindowAckSize()
    local options = { chunkStreamId = 0x02, messageStreamId = 0x00 }
    local windowAckSize = 5000000
    local message = rtmp.encodeControlMessage(MESSAGE.WINDOW_ACKNOWLEDGEMENT_SIZE, windowAckSize, options)
    self:sendData(message)
end

function RTMPClient:sendSetChunkSize()
    local chunkSize = self.peerChunkSize

    local message = rtmp.encodeControlMessage(MESSAGE.SET_CHUNK_SIZE, chunkSize)
    self:sendData(message)

    self.localChunkSize = chunkSize
end

-- 发送创建 RTMP 流请求
function RTMPClient:sendCreateStream()
    local streamName = self.streamName

    -- SET_CHUNK_SIZE
    self:sendSetChunkSize()

    -- releaseStream
    local data = { 'releaseStream', 2, null, streamName }
    self:sendCommandMessage(data)

    -- FCPublish
    data = { 'FCPublish', 3, null, streamName }
    self:sendCommandMessage(data)

    -- createStream
    data = { 'createStream', 4, null }
    return self:sendCommandMessage(data)
end

-- 发送删除 RTMP 流请求
function RTMPClient:sendDeleteStream()
    local data = { 'deleteStream', 6, null, self.streamId }
    return self:sendCommandMessage(data)
end

-- 发送推流请求
function RTMPClient:sendPublish()
    local streamName = self.streamName
    local options = { messageStreamId = self.streamId }
    options.fmt = RTMP_CHUNK_TYPE_0

    -- console.log('rtmp.sendPublish', options)

    -- publish
    -- 1. Command Name
    -- 2. Transaction ID
    -- 3. Command
    -- 4. Stream Name
    -- 5. Publishing Type "live", "record" or "append"
    local data = { 'publish', 5, null, streamName, self.appName or 'live' }
    return self:sendCommandMessage(data, options)
end

-- 发送拉流请求
function RTMPClient:sendPlay()
    local streamName = self.streamName
    local options = { messageStreamId = self.streamId }

    -- play
    -- 1. Command Name
    -- 2. Transaction ID
    -- 3. Command
    -- 4. Stream Name
    local data = { 'play', 5, null, streamName }
    return self:sendCommandMessage(data, options)
end

-- 内部方法, 发送 RTMP 命令消息
---@param data string
---@param options table
---@return boolean
function RTMPClient:sendCommandMessage(data, options)
    self:emit('request', data, options)

    local message = rtmp.encodeCommandMessage(data, options)
    return self:sendData(message)
end

-- 内部方法，发送指定的 RTMP 消息/数据包到网络层
---@param data string
function RTMPClient:sendData(data)
    local socket = self.socket
    if (socket) then
        local ret = socket:write(data)
        if (not ret) then
            self.isNotDrain = true
        end

        return ret
    end

    return false
end

-- 发送媒体元数据
function RTMPClient:sendMetadataMessage()
    if (not self.isStartStreaming) then
        return
    elseif (not self.metadata) then
        return
    end

    local metadata = self.metadata
    local array = { '@setDataFrame', 'onMetaData', metadata }
    local options = { chunkStreamId = 0x04 }
    local message = rtmp.encodeDataMessage(array, options)
    return self:sendData(message)
end

-- 内部方法，将指定的视频帧发送到网络层
---@param body string
---@param timestamp integer - in ms
function RTMPClient:sendVideoSample(body, timestamp)
    if (not self.isStartStreaming) then
        return -- 还没有开始推流
    end

    -- 发送 pps/sps 视频数据集
    if (not self.isVideoConfigurationSent) then
        if (not self.videoParameterSets) then
            return
        end

        local options = {
            chunkStreamId = 0x04,
            chunkSize = self.chunkSize,
            timestamp = 0
        }

        local sets = self.videoParameterSets
        local tagData = flv.encodeVideoConfiguration(sets.sps, sets.pps)
        local message = rtmp.encodeVideoMessage(tagData, options)
        self:sendData(message)
        self.isVideoConfigurationSent = true
    end

    self.videoSamples = (self.videoSamples or 0) + 1

    -- 发送视频包
    local options = { chunkStreamId = 0x04, timestamp = timestamp }
    options.chunkSize = self.chunkSize
    local message = rtmp.encodeVideoMessage(body, options)
    self:sendData(message)

    self.lastActiveTime = process.now()
    -- console.log('self.videoSamples', self.videoSamples, self.mediaQueue.slowMode);
end

---@param naluData string - NALU data
---@param timestamp integer - in ms
---@param isSyncPoint boolean
function RTMPClient:sendVideo(naluData, timestamp, isSyncPoint)
    local flags = queue.FLAG_IS_END
    if (isSyncPoint) then
        flags = flags | queue.FLAG_IS_SYNC
    end

    -- FLV H.264(AVC) video tag
    local naluType = naluData:byte(1) & 0x1f
    local videoHeader = flv.encodeAvcHeader(naluType, naluData, timestamp)
    local videoSample = videoHeader .. naluData

    -- 缓存要发送的数据
    self.mediaQueue:push(videoSample, timestamp, flags)
    self:flushVideoStream()
end

function RTMPClient:setMetadata(mediaInfo)
    if (not mediaInfo) then
        return
    end

    ---@type RtmpMediaInfo
    local metadata = {
        copyright = mediaInfo.copyright or 'anyou',
        width = mediaInfo.width or 1280,
        height = mediaInfo.height or 720,
        framerate = mediaInfo.framerate or 25,
        videocodecid = mediaInfo.videocodecid or 7
    }

    if (mediaInfo.audiocodecid) then
        metadata.audiosamplerate = mediaInfo.audiosamplerate or 8000
        metadata.audiocodecid = mediaInfo.audiocodecid
    end

    self.metadata = metadata
end

-- 内部方法
function RTMPClient:setState(state)
    -- console.log('setState', state, self.state);

    if (self.state == state) then
        return
    end

    self.state = state

    if (state == exports.STATE_INIT) then
        -- 开始握手
        self:sendC0C1()

    elseif (state == exports.STATE_HANDSHAKE) then
        -- 完成握手，开始连接流
        setTimeout(100, function()
            self:sendConnect()
        end)

    elseif (state == exports.STATE_PUBLISHING) then
        -- 取消连接超时定时器
        if (self.connectTimer) then
            clearTimeout(self.connectTimer)
            self.connectTimer = nil
        end

    elseif (state == exports.STATE_PLAYING) then
        -- 取消连接超时定时器
        if (self.connectTimer) then
            clearTimeout(self.connectTimer)
            self.connectTimer = nil
        end
    end

    self:emit('state', state)
end

-- 内部方法
function RTMPClient:startStreaming()
    if (self.timer) then
        return
    end

    self.isStartStreaming = true

    -- 开始推流
    self.startTime = process.hrtime() // 1000000 -- ms
    self:emit('startStreaming')
end

return exports
