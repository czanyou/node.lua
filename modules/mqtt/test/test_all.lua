local mqtt   = require('mqtt')
local packet = require('mqtt/packet')
local assert = require('assert')
local net    = require('net')

local HOST = '127.0.0.1'
local PORT = 10089

local server
local TAG = 'TEST'

local function onServerConnection(client)
    local onData, onEnd, onMessage

    console.log('client', client:address())

    function onMessage(message)
        console.log('message', message)
        console.log('message', message.messageType)

        if (message.messageType == packet.TYPE_CONNECT) then
            print('connect')

            local response = packet.Packet:new()
            response.messageType = packet.TYPE_CONACK

            local data = response:build()

            client:write(data)
        end
    end

    function onData(chunk)
        --console.log('data', chunk)
        console.printBuffer(chunk)

        local message = packet.parse(chunk)
        onMessage(message)
    end

    function onEnd(chunk)
        console.log('end', chunk)

    end

    client:on("data", onData)
    client:on("end", onEnd)
end

function startServer()
    server = net.createServer(onServerConnection)
    server:listen(PORT, HOST)
end


function startMqtt()
    local url = 'mqtt://127.0.0.1:10089'
    local client = mqtt.connect(url)

    client.keepalive = 5

    local TOPIC = '/test-topic'
    local MESSAGE = 'Hello mqtt'

    client:on('connect', function()
        print(TAG, 'event', 'connect')

        client:subscribe(TOPIC)

        print(TAG, 'subscribe', TOPIC)
        setTimeout(100, function()
            print(TAG, 'publish', TOPIC, MESSAGE)
            client:publish(TOPIC, MESSAGE)
        end)
    end)

    client:on('message', function (topic, message)
        print(TAG, 'message', topic, message)
        assert.equal(topic, TOPIC)
        assert.equal(message, MESSAGE)
        client:close()

        print(TAG, "message is OK, auto exit...")
    end)

    client:on('error', function(errInfo)
        print(TAG, 'event', 'error', errInfo)
    end)
end

startServer()

setTimeout(100, function()
    startMqtt()
end)
