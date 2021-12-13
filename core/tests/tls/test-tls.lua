local tls = require('tls')

local tap = require('util/tap')
local test = tap.test

--console.log('tls', tls)
test("tls", function(expect)
    --console.log(tls.TLSSocket)
    console.log('createCredentials', tls.createCredentials())
end);

test("tls.connect", function(expect)
    local options = {
        host = "www.baidu.com",
        port = 443
    }

    local socket = tls.connect(options, function(socket)
        console.log('connect event')

        local message = "GET / HTTP/1.0\r\nHost: www.baidu.com\r\n\r\n"
        socket:write(message)
    end)

    socket:on('data', function(data)
        console.log('data', #data)
    end)

    socket:once('end', function(err)
        console.log('end', err)
        socket:close();
    end)

    socket:once('close', function(err)
        console.log('close', err)
        socket:close();
    end)

    setTimeout(2000, function() socket:close(); end);
end);

tap.run()
