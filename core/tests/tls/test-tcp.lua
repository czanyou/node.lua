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
local net = require('net')
local tls = require('lmbedtls.tls')

local tap = require('util/tap')
local test = tap.test

local MBEDTLS_ERR_SSL_WANT_READ   = -0x6900 -- 26800 /**< Connection requires a read call. */
local MBEDTLS_ERR_SSL_WANT_WRITE  = -0x6880 -- 26752

test("test tls - connect", function(expect)
    local socket = net.Socket:new()
    local ssl = tls.new()

    local readBuffer = ''

    local function onWrite(err)
        --console.log("write")
        --assert(err == nil)
    end

    local function _write(data)
        -- console.log('write', #data)
        socket:write(data, onWrite)
        return #data
    end

    local function _read(len)
        -- console.log('read', len)
        if (#readBuffer >= len) then
            local data = readBuffer:sub(1, len)
            readBuffer = readBuffer:sub(len + 1)

            return #data, data
        end

        return MBEDTLS_ERR_SSL_WANT_READ
    end

    local function callback(data, len)
        if (len) then
            return _read(len)

        else
            return _write(data)
        end
    end

    local canRead = false

    local function onConnect()
		console.log('connect')

		local function onData(data)
            -- console.log('data', #data)
            readBuffer = readBuffer .. data

            if (canRead) then
                while (true) do
                    local size, text = ssl:read();
                    if (size <= 0) then
                        break
                    end

                    -- console.log('onread', #text)
                end
                return
            end

            -- handshake
            local ret = ssl:handshake()
            console.log('handshake', ret)
            if (ret == 0) then
                console.log('handshake is done')

                local message = "GET / HTTP/1.0\r\nHost: www.baidu.com\r\n\r\n"
                ssl:write(message)
                canRead = true
            end
        end

        local function onClose()
            console.log('close')
        end

        local function onEnd()
            socket:removeListener("data", onData)
            console.log('end')
        end

        local function onFinish()
            console.log('finish')
        end

        console.log('config', ssl:config("cn.bing.com", 0, callback))
        --console.log('connect', ssl:connect("cn.bing.com", "443"))

        socket:on("data", onData)
        socket:once('close', onClose)
        socket:once('end', onEnd)
        socket:once('finish', onFinish)

        --socket:write("ping", expect(onWrite))
        --ssl:write("test")

        ssl:handshake()
	end

    socket:connect(443, 'www.baidu.com', onConnect)
end)

tap.run()
setTimeout(5000, function() end)
