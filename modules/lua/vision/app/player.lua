local meta 		= { }
local exports 	= { meta = meta }

local lmessage 	= require('lmessage')
local thread  	= require('thread')

local handlers      = {}
local handlerCount  = 1

local function startClient(client)
    local clientThread = function(handler, url)
        local client  = require('app/client')
        local lmessage  = require('lmessage')

        -- notify
        local notify = function (name, ...)
            local queue, err = lmessage.get_queue('main')
            if (queue) then
                queue:send(handler, name, ...)
                queue:close()
                return
            end

            local app = require('application')
            if (app) then
                app.on_message(handler, name, ...)
            end
        end

        local player = client.open(url, function(...)
            notify(...)
        end)

        local interval = setInterval(100, function()
            --client.on_message(handle, index, "check");
        end)

        local threadQueue 
        local name = "player_client_" .. handler
        threadQueue = lmessage.new_queue(name, 100, function(name, ...)
            -- console.log('thread message', name, ...)

            if (name == 'close') then
                clearTimer(interval)
                interval = nil
            end
  
            local method = player[name]
            if (method) then
                local ret = method(player, ...)
                notify(name, ret)
            end
        end)
    end

    client.thread = thread.start(clientThread, tostring(client.handler), client.url)
end

function exports.clear() 


end

function exports.close(handle) 
    print('close', handle)
    if (not handle) then
        return
    end

    local client = handlers[handle]
    handlers[handle] = nil
    if (client) then
        --console.log('close', client)
        return 1
    end

    return 0    
end

function exports.control(handle, ...)
    local client = handlers[handle]
    if (client) then
        local name = "player_client_" .. client.handler

        local threadQueue, err = lmessage.get_queue(name)
        if (threadQueue) then
            threadQueue:send('control', ...)
            threadQueue:close()
        end

        return 1
    end

    return 0    
end

function exports.open(url, callback)
    local handler = 1
    local client = {}
    client.url      = url
    client.handler  = handler
    client.callback = callback
    startClient(client)

    handlers[handler] = client
    handlerCount = handlerCount + 1
    return handler
end

return exports

