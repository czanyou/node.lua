--[[

Copyright 2016 The Node.lua Authors. All Rights Reserved.

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
local cjson = require('cjson')

local meta = { }
meta.name       = "lnode/json"
meta.version    = "0.1.2"
meta.license    = "Apache 2"
meta.description = "JSON module for lnode"
meta.tags       = { "lnode", "json" }

local exports = { meta = meta }

exports.stringify = function(value, state)
    if (type(value) == 'table') and (next(value) == nil) then
        return "[]";
    end

    local status, ret = pcall(cjson.encode, value)
    if (status) then
        return ret
    end

    --print("encode", status, ret) 
    return nil, ret
end

exports.parse = function(data)
    local status, ret = pcall(cjson.decode, data)
    if (status) then
        return ret
    end

    --print("decode", status, ret)
    return nil, ret
end

exports.encode = exports.stringify
exports.decode = exports.parse
exports.null   = cjson.null

return exports
