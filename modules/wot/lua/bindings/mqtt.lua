local mqtt   = require('mqtt')

local TAG = 'mqtt'

local exports = {}

function exports.connect(urlString, clientId)
    -- console.log(urlString, clientId)

    local client = mqtt.connect(urlString)
    local topic = 'actions/' .. clientId

    client:on('connect', function()
        -- print(TAG, 'event', 'connect')

        client:subscribe(topic)
        -- print(TAG, 'subscribe', topic)
    end)

    client:on('error', function(errInfo)
        console.log(TAG, 'event', 'error', errInfo)
    end)

    exports.client = client
    exports.clientId = clientId
    return client
end

function exports.publishMessage(data)
    local client = exports.client
    if (not client) then
        return
    end

    local topic = 'messages/' .. self.clientId
    client:publish(topic, data)
end

return exports