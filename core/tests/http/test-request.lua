--[[

Copyright 2015 The Luvit Authors. All Rights Reserved.

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

local http = require('http')
local request = require('http/request')

local HOST = "127.0.0.1"
local PORT = process.env.PORT or 10082

local body = "Hello world\n"

require('ext/tap')(function(test)

test("request.get", function(expect)
    local server = nil
    local client = nil

    server = http.createServer(expect(function(request, response)
      --p('server:onConnection req', request)
      assert(request.method == "GET")
      assert(request.url == "/foo")
      -- Fixed because header parsing is not busted anymore
      -- console.log(request.headers)

      assert(request.headers.bar == "cats")
      --p('server:onConnection bare resp', response)
      response:setHeader("Content-Type", "text/plain")
      response:setHeader("Content-Length", #body)
      response:finish(body)
    end))

    server:listen(PORT, HOST, function()
        local headers = {bar = "cats"}
        local options = { headers = headers }

        local urlString = 'http://' .. HOST .. ':' .. PORT .. '/foo'
        request.get(urlString, options, expect(function(err, response, body)
            if (err) then
                server:close()
                console.log(err)
                return
            end
            
            assert(response.statusCode == 200)
            assert(response.httpVersion == '1.1')
            server:close()
        end))
    end)
end)

test("request.post.json", function(expect)
    local server = nil
    local client = nil

    server = http.createServer(expect(function(request, response)
      --p('server:onConnection req', request)
      assert(request.method == "POST")
      assert(request.url == "/foo")
      -- Fixed because header parsing is not busted anymore
      -- console.log(request.headers)

      assert(request.headers.bar == "cats")
      assert(request.headers['Content-Type'] == "application/json")

      --p('server:onConnection bare resp', response)
      response:setHeader("Content-Type", "text/plain")
      response:setHeader("Content-Length", #body)
      response:finish(body)
    end))

    server:listen(PORT, HOST, function()
        local headers = {bar = "cats"}
        local options = { headers = headers, json = headers }

        local urlString = 'http://' .. HOST .. ':' .. PORT .. '/foo'
        request.post(urlString, options, expect(function(err, response, responseBody)
            if (err) then
                server:close()
                console.log(err)
                return
            end

            -- console.log(responseBody)            
            assert(responseBody == body)
            assert(response.statusCode == 200)
            assert(response.httpVersion == '1.1')
            server:close()
        end))
    end)
end)

test("request.put.data", function(expect)
    local server = nil
    local client = nil

    server = http.createServer(expect(function(request, response)
      --p('server:onConnection req', request)
      assert(request.method == "PUT")
      assert(request.url == "/foo")
      -- Fixed because header parsing is not busted anymore
      -- console.log(request.headers)

      assert(request.headers.bar == "cats")
      assert(request.headers['Content-Type'] == "application/octet-stream")
      assert(tonumber(request.headers['Content-Length']) == #body)      

      --p('server:onConnection bare resp', response)
      response:setHeader("Content-Type", "text/plain")
      response:setHeader("Content-Length", #body)
      response:finish(body)

      request:on('data', function(data)
        -- console.log('data', data)
      end)
    end))

    server:listen(PORT, HOST, function()
        local headers = { bar = "cats" }
        local options = { headers = headers, data = body }

        local urlString = 'http://' .. HOST .. ':' .. PORT .. '/foo'
        request.put(urlString, options, expect(function(err, response, responseBody)
            if (err) then
                server:close()
                console.log(err)
                return
            end

            -- console.log(responseBody, #responseBody)            
            assert(responseBody == body)
            assert(response.statusCode == 200)
            assert(response.httpVersion == '1.1')
            server:close()
        end))
    end)
end)

test("request.delete.form", function(expect)
    local server = nil
    local client = nil

    server = http.createServer(expect(function(request, response)
      --p('server:onConnection req', request)
      assert(request.method == "DELETE")
      assert(request.url == "/foo")
      -- Fixed because header parsing is not busted anymore
      -- console.log(request.headers)

      assert(request.headers.bar == "cats")
      assert(request.headers['Content-Type'] == "application/x-www-form-urlencoded")

      --p('server:onConnection bare resp', response)
      response:setHeader("Content-Type", "text/plain")
      response:setHeader("Content-Length", #body)
      response:finish(body)

      request:on('data', function(data)
        -- console.log('data', data)
        assert(data == "bar=cats")
      end)
    end))

    server:listen(PORT, HOST, function()
        local headers = { bar = "cats" }
        local options = { headers = headers, form = headers }

        local urlString = 'http://' .. HOST .. ':' .. PORT .. '/foo'
        request.delete(urlString, options, expect(function(err, response, responseBody)
            if (err) then
                server:close()
                console.log(err)
                return
            end

            -- console.log(responseBody, #responseBody)            
            assert(responseBody == body)
            assert(response.statusCode == 200)
            assert(response.httpVersion == '1.1')
            server:close()
        end))
    end)
end)

end)
