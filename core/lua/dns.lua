--[[

Copyright 2014-2015 The Luvit Authors. All Rights Reserved.
Copyright 2016-2020 The Node.lua Authors. All Rights Reserved.

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

-- Derived from Yichun Zhang (agentzh)
-- https://github.com/openresty/lua-resty-dns/blob/master/lib/resty/dns/resolver.lua

local uv = require('luv')

local meta = {
    description = "Node-style dns module for lnode"
}

local exports = { meta = meta }

local Error  = require('core').Error

local function getError(err)
    if (err) then
        return { code = 100, message = err }
    end
end

local function getAddresses(res)
    if (not res) then return end

    local addresses = {}
    for _, value in ipairs(res) do
        table.insert(addresses, value.addr)
    end
    return addresses
end

local function getAddressRecords(res)
    if (not res) then return end

    local function getFamily(family)
        if (family == 'inet') then
            return 4
        elseif (family == 'inet6') then
            return 6
        else
            return family
        end
    end

    local addresses = {}
    for _, value in ipairs(res) do
        table.insert(addresses, { address = value.addr, family = getFamily(value.family) })
    end
    return addresses
end

function exports.lookup(hostname, options, callback)
    if (type(options) == 'function') then
        options, callback = nil, options
    end

    options = options or {}
    options.socktype = "stream"

    uv.getaddrinfo(hostname, nil, options, function(err, res)
        callback(getError(err), getAddressRecords(res))
    end)
end

function exports.resolve(name, rrtype, callback)
    if (type(rrtype) == 'function') then
        rrtype, callback = nil, rrtype
    end

    local options = { socktype = "stream" }
    if (rrtype == 'A') then
        options.family = 'inet'

    elseif (rrtype == 'AAAA') then
        options.family = 'inet6'
    end

    uv.getaddrinfo(name, nil, options, function(err, res)
        callback(getError(err), getAddresses(res))
    end)
end

function exports.resolve4(name, callback)
    exports.resolve(name, 'A', callback)
end

function exports.resolve6(name, callback)
    exports.resolve(name, 'AAAA', callback)
end

return exports
