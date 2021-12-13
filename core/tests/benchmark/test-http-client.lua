local http = require('http')

local totalBytes = 0

local function start(port, address)
    console.time('http')
    local req
    req = http.get('http://' .. address .. ':' .. port, function(res, err)
        console.log('error', err)

        res:on('data', function(data)
            -- print('data', #data, totalBytes)

            totalBytes = totalBytes + #data
            if (totalBytes >= 1500 * 1024 * 10) then
                console.timeEnd('http')
                req:finish()
            end
        end)
    end)
end

local address = '192.168.1.135'
-- address = nil
start(10088, address or '127.0.0.1')
