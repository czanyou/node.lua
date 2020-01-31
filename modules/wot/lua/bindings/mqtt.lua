local mqtt   = require('mqtt')

local TAG = 'mqtt'

local exports = {}

function exports.connect(urlString, options)
    -- console.log(urlString, clientId)

    local client = mqtt.connect(urlString, options)
    client:on('connect', function()
        -- print(TAG, 'event', 'connect')
        -- print(TAG, 'subscribe', topic)
    end)

    client:on('error', function(errInfo)
        -- console.log(TAG, 'event', 'error', errInfo)
    end)

    exports.client = client
    exports.clientId = options and options.clientId
    return client
end

function exports.publishMessage(clientId, data)
    local client = exports.client
    if (not client) then
        return
    end

    local topic = 'messages/' .. clientId
    client:publish(topic, data)
end

return exports