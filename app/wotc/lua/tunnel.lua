local net = require('net')

local exports = {}

local PORT = 8877

-- ----------------------------------------------------------------------------
-- Tunnel client
-- 用于和云服务器建议 TCP/IP 隧道，充许外网的客户端访问本地的服务

exports.createSession = function(serverPort, serverAddress, localPort, localAddress, sessionId)
    local function createLocalClient(localPort, localHost, callback)
        local localClient = nil
        local buffer = nil

        -- localClient
        localClient = net.Socket:new()
        localClient:on("error", function(error)
            console.log("local client error", error)
        end)

        localClient:on("end", function(error)
            console.log("on client local end", error)

            local remoteClient = localClient.remoteClient
            localClient.remoteClient = nil
            if (remoteClient) then
                remoteClient:close()
                remoteClient = nil
            end
        end)

        local function onLocalConnect()
            console.log('on client local connect')

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

            localClient:on("data", onData)

            if (callback) then
                callback(localClient)
            end
        end

        console.log('createLocalClient', localPort, localHost)

        localClient:connect(localPort, localHost, onLocalConnect)
        return localClient
    end

    local function createRemoteClient(remotePort, remoteHost, sessionId, localClient)
        local remoteClient = nil

        console.log('createRemoteClient', remotePort, remoteHost)
    
        -- remoteClient
        remoteClient = net.Socket:new()
        remoteClient:on("error", function(error)
            console.log("remote client error", error)
        end)

        remoteClient:on("end", function(error)
            console.log("on client remote end", error)

            if (localClient) then
                localClient:close()
                localClient = nil
            end
        end)

        local function onRemoteConnect()
            console.log('on client remote connect')
            localClient.remoteClient = remoteClient

            local onData = function(data)
                -- console.log('on client remote data', data)

                localClient:write(data)
            end

            remoteClient:on("data", onData)
            remoteClient:write("tunnel\n" .. sessionId .. "\n\n")
        end

        remoteClient:connect(remotePort, remoteHost, onRemoteConnect)
    end

    local remotePort = serverPort
    local remoteHost = serverAddress

    console.log('createSession', serverPort, serverAddress)

    local localClient = createLocalClient(localPort, localAddress, function(localClient)
        createRemoteClient(remotePort, remoteHost, sessionId, localClient)
    end)

    return localClient
end

-- 创建一个新的隧道客户端
-- @param {Number} serverPort 隧道服务器端口
-- @param {String} serverAddress 隧道服务器地址
-- @param {Number} localPort 要代理的本地服务器端口
-- @param {String} localAddress 要代理的本地服务器地址
exports.createClient = function(serverPort, serverAddress, localPort, localAddress, callback)
    localAddress = localAddress or '127.0.0.1'

	local client = net.Socket:new()
	client:on("error", function(error)
        console.log("client error", error)
    end)

    client.connections = {}

    local function onPingTimer()
		local function onWrite(err)
			
        end
        
        client:write("ping\n\n", onWrite)
    end

    local function onRequestMessage(lines)
        local sessionId = lines[2]
        local connection = client.connections[sessionId]
        if (connection) then
            return connection
        end

        connection = exports.createSession(serverPort, serverAddress, localPort, localAddress, sessionId)
        if (connection) then
            client.connections[sessionId] = connection
        end

        return connection
    end

    local function onPongMessage(lines)
        local port = lines[2]
        local token = lines[3]
        client.port = port
        client.token = token

        if (callback) then
            callback(port, token)
        end
    end

    local function onClientConnect()
        console.log('tunnel client on connect')
        
        local buffer

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
            client.isEnd = true
        end

        client:on("data", onData)
        client:on("end", onEnd)

        onPingTimer()

        if (not client.pingTimer) then
            client.pingTimer = setInterval(10000, onPingTimer)
        end
	end

    client:connect(serverPort, serverAddress, onClientConnect)
    return client
end

exports.start = function(localPort, localAddress, callback)
    local client = exports.client
    if (client) then
        if (callback) then
            callback(client.port, client.token)
        end
        return client
    end

    localPort = tonumber(localPort or 80)
    localAddress = localAddress or '127.0.0.1'
    console.log('start tunnel (local address)', localAddress, localPort)

    local remotePort = PORT
    local remoteAddress = 'www.wotcloud.cn'
    client = exports.createClient(remotePort, remoteAddress, localPort, localAddress, function(port, token)
        if (callback) then
            callback(port, token)
            callback = nil
        end
    end)

    exports.client = client

    return client
end

exports.stop = function()
    local client =  exports.client
    exports.client = nil
    if (client) then
        local connections = client.connections or {}
        for index, connection in ipairs(connections) do
            local remoteClient = connection.remoteClient
            connection.remoteClient = nil
            if (remoteClient) then
                remoteClient:close()
            end

            connection:close()
        end

        client.connections = {}
        client:close()
    end
end

return exports