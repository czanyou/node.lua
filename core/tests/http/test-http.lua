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
local decoder = require('http/codec').decoder
local encoder = require('http/codec').encoder
local uv = require('luv')

local tap = require('util/tap')
local test = tap.test

test("Real HTTP request", function(expect)
    local options = { socktype = "stream", family = "inet" }
    uv.getaddrinfo("luvit.io", "http", options, expect(function(err, res)
        assert(not err, err)
        local client = uv.new_tcp()
        local address = res[1]
        client:connect(address.addr, address.port, expect(function(err)
            assert(not err, err)
            console.log{ client = client, sock = client:getsockname(), peer = client:getpeername(), }

            -- request
            local encode, decode = encoder(), decoder()
            local req = {
                method = "GET", path = "/",
                {"Host", "luvit.io"},
                {"User-Agent", "lnode"},
                {"Accept", "*/*"},
            }
            console.log('request', req)
            client:write(encode(req))

            -- read_start
            local parts = {}
            local data = ""
            local finish

            client:read_start(--[[expect--]](function(err, chunk)
                console.log('read_start', err, chunk and #chunk)

                assert(not err, err)
                if not chunk then
                    return finish()
                end
                data = data .. chunk

                -- decode
                repeat
                    local event, extra = decode(data)
                    if event then
                        parts[#parts + 1] = event
                        if event == "" then return finish() end
                        data = extra
                    end
                until not event
            end))

            -- finish
            finish = expect(function()
                console.log('finish')

                client:read_stop()
                client:close()

                -- response
                local response = table.remove(parts, 1)
                console.log('response', response.code)

                -- luvit.io should redirect to https version
                -- assert(response.code == 301)
                assert(response.code == 200)

                -- contentLength
                local contentLength
                for i = 1, #response do
                    if string.lower(response[i][1]) == "content-length" then
                        contentLength = tonumber(response[i][2])
                        break
                    end
                end

                for i = 1, #parts do
                    local item = parts[i]
                    contentLength = contentLength - #item
                    console.log('finish:', #item, contentLength)
                end

                assert('contentLength', contentLength)
                assert(contentLength == 0)
            end)
        end))
    end))
end)
