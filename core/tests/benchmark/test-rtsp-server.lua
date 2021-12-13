local server  = require('rtsp/server')

local function start(listPort)

    print('Start RTSP server at ('.. listPort .. ') ...')
    local rtspServer = server.startServer(listPort, function(connection, pathname)
        console.log('rtspServer', connection.connectionId, pathname)
        -- return: media session
        
        local mediaSession = {}
        return mediaSession
    end)

    -- auth
    --[[
    rtspServer:setAuthCallback(function(username)
        local password = '12345'
        console.log('auth', username, password)
		return password
    end)
    --]]

    rtspServer:on('connection', function(connection)
        console.log('connection', connection.connectionId)

        connection:on('sample', function(sample)
            console.log('sample')
        end)
    end)

    rtspServer:on('error', function(error)
        console.log('error', error)
    end)

    rtspServer:on('close', function(error)
        console.log('close', error)
    end)
end



start(10554)