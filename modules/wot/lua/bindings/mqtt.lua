local mqtt   = require('mqtt')

local exports = {}

-- start connect to MQTT server
---@param urlString string
---@param options any
function exports.connect(urlString, options)
    if (not urlString) then
        return
    end
    -- console.log(urlString, options)

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

-- Publish message
---@param did string
---@param message any
function exports.publishMessage(did, message)
    local client = exports.client
    if (not client) then
        return
    end

    if (not did) or (not message) then
        return
    end

    local topic = 'messages/' .. did
    client:publish(topic, message)
end

return exports