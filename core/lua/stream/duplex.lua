--[[

Copyright 2014 The Luvit Authors. All Rights Reserved.
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
local utils = require('util')
local timer = require('timer')

local Readable = require('stream/readable').Readable
local Writable = require('stream/writable').Writable

local Duplex = Readable:extend()

local _onEnd

for k, v in pairs(Writable) do
    if not Duplex[k] and k ~= 'meta' then
        Duplex[k] = v
    end
end

function Duplex:initialize(options)
    Readable.initialize(self, options)
    Writable.initialize(self, options)

    if options and options.readable == false then
        self.readable = false
    end

    if options and options.writable == false then
        self.writable = false
    end

    self.allowHalfOpen = true
    if options and options.allowHalfOpen == false then
        self.allowHalfOpen = false
    end

    self:once('end', utils.bind(_onEnd, self))
end

--[[
// the no-half-open enforcer
--]]
function _onEnd(self)
    --[[
  // if we allow half-open state, or if the writable side ended,
  // then we're ok.
  --]]
    if self.allowHalfOpen or self._writableState.ended then
        return
    end

    --[[
  // no more data can be written.
  // But allow more writes to happen in this tick.
  --]]
    timer.setImmediate(utils.bind(self._end, self))
end

local exports = { }

exports.Duplex = Duplex

return exports
