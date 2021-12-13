local net = require('net')

local exports = {}

local PORT = 8877

-- ----------------------------------------------------------------------------
-- Tunnel client
-- 用于和云服务器建议 TCP/IP 隧道，充许外网的客户端访问本地的服务

exports.createSession = function(options, sessionId)
    -- 创建和本地服务的连接
    ---@param localPort integer
    ---@param localAddress string
    ---@param callback function
    local function createLocalClient(localPort, localAddress, callback)
        local localClient = nil
        local buffer = nil

        -- localClient
        localClient = net.Socket:new()

        -- error
        localClient:on("error", function(error)
            console.log("local client error", error)
        end)

        -- end
        localClient:on("end", function(error)
            console.log("on client local end", error)

            local remoteClient = localClient.remoteClient
            localClient.remoteClient = nil
            if (remoteClient) then
                remoteClient:close()
                remoteClient = nil
            end
        end)

        -- data
        local onData = function(chunk)
            -- console.log('on client local data', chunk)

            local remoteClient = localClient.remoteClient
            if (remoteClient) then
                if (buffer) then
                    remoteClient:write(buffer)
                    buffer = nil
                end

                remoteClient:write(chunk)
                return
            end

            if (buffer) then
                buffer = buffer .. chunk
            else
                buffer = chunk
            end
        end

        -- connected
        local function onLocalConnect()
            console.log('on client local connect')
            localClient:on("data", onData)

            if (callback) then
                callback(localClient)
            end
        end

        -- connect
        console.log('createLocalClient', localPort, localAddress)
        localClient:connect(localPort, localAddress, onLocalConnect)

        localClient.localPort = localPort
        localClient.localAddress = localAddress
        return localClient
    end

    -- 创建和远端代理服务器的连接
    ---@param serverPort integer
    ---@param serverAddress string
    ---@param sessionId string
    ---@param localClient any
    local function createRemoteClient(serverPort, serverAddress, sessionId, localClient)
        local remoteClient = nil

        -- remoteClient
        remoteClient = net.Socket:new()

        -- error
        remoteClient:on("error", function(error)
            console.log("remote client error", error)
        end)

        -- end
        remoteClient:on("end", function(error)
            console.log("on client remote end", error)
            remoteClient.isEnd = true

            if (localClient) then
                localClient:close()
                localClient = nil
            end
        end)

        -- data
        local onRemoteData = function(data)
            -- console.log('on client remote data', data)

            localClient:write(data)
        end

        -- connected
        local function onRemoteConnect()
            console.log('on client remote connect')
            localClient.remoteClient = remoteClient
            remoteClient.connected = true

            remoteClient:on("data", onRemoteData)
            remoteClient:write("tunnel\n" .. sessionId .. "\n\n")
        end

        -- connect
        console.log('createRemoteClient', serverPort, serverAddress)
        remoteClient:connect(serverPort, serverAddress, onRemoteConnect)
    end

    local serverPort = options.serverPort
    local serverAddress = options.serverAddress

    -- connect
    console.log('createSession', serverPort, serverAddress)
    local localClient = createLocalClient(options.localPort, options.localAddress, function(localClient)
        createRemoteClient(serverPort, serverAddress, sessionId, localClient)
    end)

    return localClient
end

-- 创建一个新的隧道客户端
-- @param {Number} serverPort 隧道服务器端口
-- @param {String} serverAddress 隧道服务器地址
-- @param {Number} localPort 要代理的本地服务器端口
-- @param {String} localAddress 要代理的本地服务器地址
-- serverPort, serverAddress, localPort, localAddress,
exports.createClient = function(options, callback)
	local tunnelClient = net.Socket:new()
	tunnelClient:on("error", function(error)
        console.log("client error", error)
    end)

    tunnelClient.connections = {}
    tunnelClient.isEnd = false
    tunnelClient.serverConnected = false

    local remotePort = options.remotePort

    -- ping
    local function onPingTimer()
		local function onWrite(err)

        end

        local request = "ping\n"
        if (remotePort) then
            request = request .. remotePort .. "\n"
        end

        request = request .. "\n"
        console.log('ping', remotePort, request)

        tunnelClient:write(request, onWrite)
    end

    local function onRequestMessage(lines)
        local sessionId = lines[2]
        local connection = tunnelClient.connections[sessionId]
        if (connection) then
            return connection
        end

        connection = exports.createSession(options, sessionId)
        if (connection) then
            tunnelClient.connections[sessionId] = connection
        end

        return connection
    end

    -- pong
    local function onPongMessage(lines)
        local port = lines[2]
        local token = lines[3]
        tunnelClient.port = port
        tunnelClient.token = token
        tunnelClient.lastPongTime = Date.now()

        if (callback) then
            callback(port, token)
        end
    end

    -- connect
    local function onClientConnect()
        console.log('tunnel client - on connect')

        tunnelClient.serverConnected = true
        local buffer

        -- message
        local function onMessage(message)
            -- console.log('client message', message)
            local lines = string.split(message, '\n')

            -- console.log(lines)
            local type = lines[1]
            -- console.log('client message', type)

            if (type == 'request') then
                console.log('client message', type)
                onRequestMessage(lines)

            elseif (type == 'pong') then
                onPongMessage(lines)
            end
        end

        -- data
        local function onData(chunk)
            -- console.log('data', chunk)

            if (buffer) then
                buffer = buffer .. chunk
            else
                buffer = chunk
            end

            while (buffer and #buffer > 0) do
                local position = string.find(buffer, '\n\n')
                if (not position) then
                    break
                end

                local message = string.sub(buffer, 1, position + 1)
                buffer = string.sub(buffer, position + 2)

                onMessage(message)
                -- console.log('message', message, buffer)
            end
		end

        local function onEnd(err)
            console.log("tunnel client:end", err)
            tunnelClient.isEnd = true
        end

        tunnelClient:on("data", onData)
        tunnelClient:on("end", onEnd)

        onPingTimer()

        if (not tunnelClient.pingTimer) then
            tunnelClient.pingTimer = setInterval(10 * 1000, onPingTimer)
        end
    end

    tunnelClient.remotePort = options.remotePort
    tunnelClient.serverPort = options.serverPort
    tunnelClient.serverAddress = options.serverAddress

    tunnelClient:connect(options.serverPort, options.serverAddress, onClientConnect)
    return tunnelClient
end

exports.getStatus = function()
    local status = { code = 0 }

    local client = exports.client
    -- console.log('client', client)

    if (client) then
        status.port = client.port
        status.token = client.token
        status.destroyed = client.destroyed
        status.isEnd = client.isEnd
        status.lastPongTime = client.lastPongTime

        status.serverPort = client.serverPort
        status.serverAddress = client.serverAddress
        status.serverConnected = client.serverConnected
    end

    status.sessions = {}
    local sessions = client and client.connections
    if (sessions) then
        for name, session in pairs(sessions) do
            local info = {
                localPort = session.localPort,
                localAddress = session.localAddress
            }

            local remoteClient = session.remoteClient
            if (remoteClient) then
                info.remoteConnected = remoteClient.connected
            end

            status.sessions[name] = info
        end
    end

    return status
end

exports.start = function(options, callback)
    local tunnelClient = exports.client
    if (tunnelClient) then
        if (callback) then
            callback(tunnelClient.port, tunnelClient.token)
        end
        return tunnelClient
    end

    exports.options = options

    options.localPort = tonumber(options.localPort) or 80
    options.localAddress = options.localAddress or '127.0.0.1'
    console.log('start tunnel (local address)', options.localAddress, options.localPort)

    options.remotePort = tonumber(options.remotePort) or 40000
    options.remoteAddress = options.remoteAddress or 'iot.wotcloud.cn'

    options.serverPort = tonumber(options.serverPort) or PORT
    options.serverAddress = options.remoteAddress or 'iot.wotcloud.cn'

    tunnelClient = exports.createClient(options, function(port, token)
        if (callback) then
            callback(port, token)
            callback = nil
        end
    end)

    exports.client = tunnelClient

    return tunnelClient
end

exports.stop = function()
    local tunnelClient =  exports.client
    exports.client = nil
    if (tunnelClient) then
        local connections = tunnelClient.connections or {}
        for index, connection in ipairs(connections) do
            local remoteClient = connection.remoteClient
            connection.remoteClient = nil
            if (remoteClient) then
                remoteClient:close()
            end

            connection:close()
        end

        tunnelClient.connections = {}
        tunnelClient:close()
    end
end

return exports