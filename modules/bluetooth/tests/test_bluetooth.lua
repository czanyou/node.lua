local bluetooth = require('bluetooth')

console.log(bluetooth)

local SCAN_RESPONSE = 0x04

local onData = function(data)
    if (not data) then
        --if err then console.log(err) end
        return
    end

    console.printBuffer(data)

    if data:byte(6) ~= SCAN_RESPONSE then
        return
    end
        
    local length = data:byte(15)
    local flag1  = data:byte(16)
    local flag2  = data:byte(17)
    local flag3  = data:byte(18)

    if (flag1 ~= 0xff) then
        return
    end

    console.printBuffer(data)
    local temp = data:byte(19) .. "." .. data:byte(20)
    local humi = data:byte(21) .. "%"

    temp = (math.floor(temp * 10) / 10) .. '`C'
    print(temp, humi)
end

bluetooth.requestDevice(function(err, device)
    if (err) then
        console.log('err', err)
        return
    end

    console.log('device', device)

    device:watchAdvertisements()
    device:on('data', onData)
    
    setTimeout(2000, function()
        device:unwatchAdvertisements()
        device:close()
        print('stop scan...')
    end)
end)
