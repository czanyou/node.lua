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

local http  = require('http')
local url   = require('url')
local utils = require('utils')

local request = require('http/request')

local urlString = 'http://test.com:80/download/upload.php?v=1'
local line = string.rep('a', 1024)
local data = string.rep(line, 1)

local files = { file = { name = 'test.txt', data = data }}

request.post(urlString, { files = files }, function(err, response, body)
    print('body:', body)
end)

run_loop()
