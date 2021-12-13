local http = require('http')

local function start(port, address)

    local chunk = string.rep('n', 1500)
    local totalBytes = 0
    local count = 0
    
    local function onSend(res)
        count = count + 1

        while true do
            totalBytes = totalBytes + #chunk
            local ret = res:write(chunk)

            if (totalBytes >= 1500 * 1024 * 10) then
                res:finish()
                break
            end

            if (not ret) then
                break
            end
        end
    end

    -- server
    local server
    server = http.createServer(function(req, res)
        console.log('request', req.path)

        totalBytes = 0
        count = 0

        res:on('close', function()
            print('response: close(r)')
        end)

        res:on('end', function()
            print('response: end(r)')
        end)

        res:on('drain', function()
            print('response: drain(r)', count)

            onSend(res)
        end)

        onSend(res)
    end)

    -- client
    server:listen(port, function()
        print('Server running ' .. port)
    end)
end

start(10088)
