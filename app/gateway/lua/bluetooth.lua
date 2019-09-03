local app = require("app")
local path = require("path")
local fs = require("fs")
local uv = require("luv")
local wot = require("wot")
local modbus = require("lmodbus")
local math = require("math")
local json = require("json")
local exports = {}
local bluetoothUart = require("./bluetooth/uart")
local bluetoothGap = require("./bluetooth/gap")
-- local bluetoothGatt = require("./bluetooth/gatt")




local white_list = {}

local dataReady = 0









function Sleep(n)
    os.execute("sleep " .. n)
end



local bluetoothRdady = 0

local deviceStatusTimer

local BOARDCAST_CHANNEL = 0xff
local CONFIG_CHANNEL    = 0x00





local function classifyBluetoothMessages(messages)
    local channel = string.byte(messages, 1)
    local tempMessage = string.sub(messages,2,#messages)
    if (channel == BOARDCAST_CHANNEL) then
        bluetoothGap.analysisMsg(app.bluetoothDevices,white_list,tempMessage)
    elseif (channel == CONFIG_CHANNEL) then
        console.log(tempMessage)
    
    else

    end
end

local function getBluetoothMessages(messages)
    setImmediate(classifyBluetoothMessages,messages)
end


local function setBluetoothConfig(code, data)
    local ret
    local i
    local start = 0x48
    local channel = 0x00
    local temp = {}
    math.randomseed(os.time())
    local seq = math.random(0, 255)

    local len = #data + 4
    ret =
        string.char(start) ..
        string.char(channel) ..
            string.char(len & 0xff) .. string.char(len >> 8) .. string.char(code) .. string.char(seq)
    if (data ~= nil) then
        ret = ret .. data
    end

    for i = 1, len + 4 do
        temp[i] = string.byte(ret, i)
    end
    local crc = crc16_calculate(temp, len + 2)
    ret = ret .. string.char(crc & 0xff) .. string.char(crc >> 8)

    fs.writeSync(fd, nil, ret)
end


local flag = 0

local function createBluetoothThing(options)
    local webThing = {}
    if (not options) then
        return nil, "need options"
    elseif (not options.mqtt) then
        return nil, "need MQTT url option"
    elseif (not options.did) then
        return nil, "need did option"
    end

    table.insert(white_list, options.did)
    local bluetooth = {
        clientId = options.clientId,
        id = options.did,
        url = options.mqtt,
        name = options.name or "bluetooth",
        actions = {},
        properties = {},
        events = {}
    }
    -- console.log(bluetooth)
    webThing = wot.produce(bluetooth)
    webThing.secret = options.secret

    webThing:expose()

    webThing:on(
        "register",
        function(response)
            local result = response and response.result
            if (result and result.code and result.error) then
                console.log("register", "error", response.did, result)
            elseif (result.token) then
                console.log("register", response.did, result.token)
            end
        end
    )
    if (flag == 0) then
        flag = 1
        bluetoothUart.initUart(getBluetoothMessages);
        setBluetoothConfig(0x01, "scan=BN5003,0D0611")
        setInterval(100*60, function()
            setBluetoothConfig(0x01, "scan")

        end)

        setInterval(10000, function()
            bluetoothRdady = 0
            setBluetoothConfig(0x01, "test")
        end)
    end
    return webThing
end

function exports.dataStatus()
    return dataReady
end


function exports.bluetoothStatus()
    return bluetoothRdady
end

exports.createBluetooth = createBluetoothThing
return exports
