--[[

Copyright 2014-2015 The Luvit Authors. All Rights Reserved.
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

local meta = { }
meta.name 		 = "lnode/stream"
meta.version 	 = "1.1.0-4"
meta.license 	 = "Apache 2"
meta.description = "A port of node.js's stream module for lnode."
meta.tags 		 = { "lnode", "stream" }

local exports = { meta = meta }

local list = {
	Duplex 		= 'stream/duplex',
	Readable 	= 'stream/readable',
	Transform 	= 'stream/transform',
	Writable 	= 'stream/writable'
}

--[[
exports.Duplex 		= require('stream/duplex').Duplex
exports.Readable 	= require('stream/readable').Readable
exports.Transform 	= require('stream/transform').Transform
exports.Writable 	= require('stream/writable').Writable
--]]

setmetatable(exports, {
	__index = function(self, key)
		local ret = rawget(self, key)
		if (ret) then
			return ret
		end

		local file = list[key]
		if (not file) then
			return nil
		end

		local module = require(file)
		if (not module) then
			return nil
		end

		ret = rawget(module, key)
		if (ret) then
			rawset(self, key, ret)
		end

		return ret
	end
})

return exports
