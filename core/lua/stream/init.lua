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

local meta = {
	description = "A port of node.js's stream module for lnode."
}

local exports = { meta = meta }

exports.Duplex 		= require('stream/duplex').Duplex
exports.Readable 	= require('stream/readable').Readable
exports.Transform 	= require('stream/transform').Transform
exports.Writable 	= require('stream/writable').Writable

return exports
