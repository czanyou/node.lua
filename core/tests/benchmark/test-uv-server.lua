local uv = require('luv')

-- create a server socket
local function start(port, address)
    local server = uv.new_tcp()
    uv.tcp_bind(server, address or "0.0.0.0", port, function()
        console.log('uv server', port)
    end)

    uv.listen(server, 128, function()
        local client = uv.new_tcp()
        uv.accept(server, client)

        console.log('uv client', client)

        -- wait hello from client
        uv.read_start(client, function(err, data)
            if data then
                uv.write(client, data)
            end
        end, 2)
    end)
end

start(10088)

