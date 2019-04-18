local util  	= require('util')
local net 		= require('net')
local tls 		= require('tls')

local tap = require("ext/tap")
local test = tap.test

--console.log('tls', tls)
test("tls", function(expect)
    --console.log(tls.TLSSocket)
    console.log(tls.createCredentials())
    

end);

test("tls.connect", function(expect)
    local options = {
        host = "www.baidu.com",
        port = 443
    }

    local client = tls.connect(options, function(client)
        console.log('client')

        local message = "GET / HTTP/1.0\r\nHost: www.baidu.com\r\n\r\n"
        client:write(message)
    end)

    setTimeout(2000, function() client:close(); end);
end);

tap.run()
