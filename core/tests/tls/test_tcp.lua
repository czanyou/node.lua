--[[

Copyright 2014 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]
local net       = require("net")
local tls 		= require('lmbedtls.tls')
local utils 	= require('util')
local lcrypto 	= require('tls/lcrypto')

local tap = require("ext/tap")
local test = tap.test

local MBEDTLS_ERR_SSL_WANT_READ   = -0x6900 -- 26800 /**< Connection requires a read call. */
local MBEDTLS_ERR_SSL_WANT_WRITE  = -0x6880 -- 26752

test("socket timeout", function(expect)
    local client = net.Socket:new()
    local ssl = tls.new()

    local lastdata = ''

    function onWrite(err)
        --console.log("write")
        --assert(err == nil)
    end
    
    local function callback(data, len)
        --console.log('callback', data, len);

        if (len) then
            --console.log('callback.recv', len)

            if (#lastdata >= len) then
                local data = lastdata:sub(1, len)
                lastdata = lastdata:sub(len + 1)

                return #data, data
            end

            return MBEDTLS_ERR_SSL_WANT_READ

        else
            --console.log('send', #data, data)
            --console.printBuffer(data)

            client:write(data, onWrite)
            return #data
        end
    end

    local canRead = false

    function onConnect()
		console.log('connect')
		local onData, onWrite

		function onData(data)
            console.log('data', #data)

            lastdata = lastdata .. data
            
            local ret = ssl:handshake()
            --console.log('handshake', string.format("%d", ret)) -- 0x7200

            if (ret == 0) then
                local message = "GET / HTTP/1.0\r\nHost: www.baidu.com\r\n\r\n"
                ssl:write(message)
                canRead = true
            end

            if (canRead) then
                while (true) do
                    local size, text = ssl:read();
                    if (size <= 0) then
                        break
                    end

                    console.log(text)
                end
            end
		end
        
        console.log('config', ssl:config("cn.bing.com", 0, callback))
        --console.log('connect', ssl:connect("cn.bing.com", "443"))

		client:on("data", onData)
        --client:write("ping", expect(onWrite))
        
        --ssl:write("test")

        ssl:handshake()
	end

    client:connect(443, 'www.baidu.com', onConnect)


    setTimeout(5000, function() end)
end)

tap.run()
