local net = require('net')
local rpc = require('app/rpc')

local exports = {}

local PORT = 8877

-- ----------------------------------------------------------------------------
-- tunnels

-- Main Server
-- |- connections
-- |  |- clientConnection -----------|
-- |  |- clientConnection --|        |
-- |- TunerServers          |        |
-- |  |- TunerServer -- connection   |
-- |     |- connections        |
-- |        |- clientConnection -- remoteConnection
-- |- tunnelSessions
--    |- tunnelSession

local tunnelServers = {} -- 隧道服务, 每个前端对应一个隧道服务，每个隧道服务有一个公网 IP
local tunnelSessions = {}
local mainServer = nil -- 入口服务

-- 创建 tunnel 服务器
-- @param {number} port 侦听端口
-- @param {string} key 服务器编号
-- @return {TunnelServer} 返回创建的 tunnel 服务
exports.tunnel = function(port, key)

    local tunnelServer = nil
    
    local function onServerConnection(connection)
        local address = connection:address()
        console.log('tunnel server connection', address.ip)
        local key = 'T' .. address.ip .. ':' .. address.port
        connection.id = key
        tunnelServer.connections[key] = connection

        local buffer
 
        -- 设置这个客户端连接的远端连接
        function connection:setRemoteConnection(remoteConnection)
            console.log('set remote tunnel connection')
            self.remoteConnection = remoteConnection

            if (buffer) and (remoteConnection) then
                remoteConnection:write(buffer)
                buffer = nil
            end
        end

        -- 请求前端设备创建一个新的连接
        local function createRequest()
            tunnelSessions[key] = connection
   
            local tunnelConnection = tunnelServer.connection
            if (tunnelConnection) then
                tunnelConnection:write('request\n' .. key .. '\n\n')
            end
        end

        local function onData(chunk)
            console.log('on tunnel client data', #chunk)

            if (connection.remoteConnection) then
                -- 转发客户端发送的数据给远端连接
                local address = connection.remoteConnection:address()
                console.log('remote', address.port)

                if (buffer) then
                    connection.remoteConnection:write(buffer)
                    buffer = nil
                end

                connection.remoteConnection:write(chunk)

            else
                -- 缓存客户端发送的数据
                console.log('data: remote connection is null')
                if (buffer) then
                    buffer = buffer .. chunk
                else
                    buffer = chunk
                end
            end
        end
        
        local function onEnd()
            -- 关闭这个连接相关的远端连接
            if (connection.remoteConnection) then
                connection.remoteConnection:close()
                connection.remoteConnection = nil
            end

            tunnelServer.connections[key] = nil
            tunnelSessions[key] = nil
        end

        createRequest()

        connection:on("data", onData)
        connection:on("end", onEnd)
    end

    tunnelServer = net.createServer(onServerConnection)
    tunnelServer.connections = {}

    tunnelServer:on("error", function(error)
        console.log("tunnel error", error)
    end)

    tunnelServer:on("close", function(error)
        console.log("tunnel server close (error, key)", error, key, tunnelServer.connections)
        tunnelServers[key] = nil
    end)

    console.log('create a new tunnel server (port, key)', port, key)
    tunnelServer:listen(port)
    tunnelServer.key = key;

    tunnelServers[key] = tunnelServer
    return tunnelServer
end

-- ----------------------------------------------------------------------------
-- server

local function onServerConnection(connection)
    local address = connection:address()
    console.log('on server connection (peer address)', address.ip, address.port)
    local buffer

    local key = 'S' .. address.ip .. ':' .. address.port
    connection.id = key
    mainServer.connections[key] = connection
    -- console.log('connections', mainServer.connections)

    -- 设置这个前端连接的远端连接
    function connection:setRemoteConnection(remoteConnection)
        console.log('set remote client connection')
        self.remoteConnection = remoteConnection

        if (buffer) and (remoteConnection) then
            remoteConnection:write(buffer)
            buffer = nil
        end
    end

    local function createTunnelServer()
        local address = connection:address()
        local key = address.ip .. ':' .. address.port
        local publicPort = math.random(40000, 50000)
        local tunnelServer = exports.tunnel(publicPort, key)
        tunnelServer.connection = connection
        tunnelServer.publicPort = publicPort
        tunnelServer.token = key

        return tunnelServer
    end

    -- 创建一个相关的 TunnelServer
    local function onPingMessage(lines)
        local tunnelServer = connection.tunnelServer
        if (not tunnelServer) then
            tunnelServer = createTunnelServer()
            connection.tunnelServer = tunnelServer
        end

        connection.lastPingTime = Date.now()
        connection:write('pong\n' .. tunnelServer.publicPort .. '\n' .. tunnelServer.token .. '\n\n')
    end

    -- 这是一个 tunnel 连接，需要绑定到相关的客户端连接
    local function onTunnelMessage(lines)
        if (connection.remoteConnection) then
            -- 已经绑定了一个连接
            return
        end

        local key = lines[2]

        local proxyConnection = tunnelSessions[key]
        if (not proxyConnection) then
            -- 指定的会话不存在

            return
        end

        console.log('create a proxy connection', proxyConnection:address().port)
        connection:setRemoteConnection(proxyConnection)
        proxyConnection:setRemoteConnection(connection)
    end

    local function onMessage(message)
        local lines = string.split(message, '\n')
        -- console.log(lines)

        local type = lines[1]
        -- console.log('server message', type)

        if (type == 'ping') then
            onPingMessage(lines)

        elseif (type == 'tunnel') then
            onTunnelMessage(lines)
        end
    end

    local function onData(chunk)
        -- console.log('data', chunk)

        if (connection.remoteConnection) then
            connection.remoteConnection:write(chunk)
            return
        end

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
        end
    end

    local function onEnd(error)
        console.log('on server connection end', error)
        if (connection.remoteConnection) then
            connection.remoteConnection:close()
            connection.remoteConnection = nil
        end

        if (connection.tunnelServer) then
            connection.tunnelServer:close()
            connection.tunnelServer = nil
        end

        mainServer.connections[key] = nil
    end

    connection:on("data", onData)
    connection:on('end', onEnd)
end

exports.server = function()
    if (mainServer) then
        return mainServer
    end

    mainServer = net.createServer(onServerConnection)
    mainServer.connections = {}

    mainServer:on("error",function(error)
        console.log("server error", error)
    end)

    mainServer:listen(PORT)

    print('Tunnel server listen at: ', PORT)
    return mainServer
end

function exports.rpc()
    local handler = {}
    local name = 'tunneld'

    handler.status = function(handler)
        -- console.log('status', mainServer, tunnelServers, tunnelSessions)

        local status = {}

        if (mainServer) then
            status.server = {
                port = PORT,
                connections = {}
            }
    
            for key, connection in pairs(mainServer.connections) do
                local remoteConnection = connection.remoteConnection
                local remoteId = remoteConnection and remoteConnection.id

                table.insert(status.server.connections, {
                    id = connection.id,
                    server = connection.tunnelServer ~= nil,
                    remote = remoteId
                })
            end
        end
    
        status.tunnelServers = {}
    
        for key, tunnelServer in pairs(tunnelServers) do
            local connections = {}
            table.insert(status.tunnelServers, {
                id = tunnelServer.key,
                publicPort = tunnelServer.publicPort,
                connections = connections
            })

            for name, connection in pairs(tunnelServer.connections) do
                local remoteConnection = connection.remoteConnection
                local remoteId = remoteConnection and remoteConnection.id
                table.insert(connections, {
                    id = connection.id, remote = remoteId
                })
            end
        end
    
        status.tunnelSessions = {}
    
        for key, tunnelSession in pairs(tunnelSessions) do
            table.insert(status.tunnelSessions, {
                id = tunnelSession.id
            })
        end

        return status
    end

    rpc.server(name, handler, function(event, ...)
        print('rpc', event, ...)
    end)
end

function exports.start()
    exports.server()
    exports.rpc()
end

return exports
