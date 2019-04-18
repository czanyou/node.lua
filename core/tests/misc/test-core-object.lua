--[[

Copyright 2012-2014 The Luvit Authors. All Rights Reserved.

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
local tap = require("ext/tap")
local test = tap.test

local core = require("core")

test(
	"Foo:new returns new instances",
	function()
		local Foo = core.Object:extend()
		function Foo:initialize(bar)
			self.bar = bar
		end

		function Foo.meta.__tostring(table)
			return tostring(table.bar)
		end

		local Baz = Foo:extend()

		local foo1 = Foo:new(1)
		local foo2 = Foo:new(1)
		assert(foo1 ~= foo2)

		assert(tostring(foo1) == tostring(foo2))
		assert(foo1.bar == foo2.bar)

		local msg = "asd"
		local baz1 = Baz:new(msg)
		assert(tostring(baz1) == msg)

		console.log(baz1)
		console.log(core.instanceof(baz1, Baz))
		console.log(core.instanceof(baz1, Foo))
		console.log(core.instanceof(baz1, core.Object))

		console.log(foo1)
		console.log(core.instanceof(foo1, Baz))
		console.log(core.instanceof(foo1, Foo))
		console.log(core.instanceof(foo1, core.Object))
	end
)

tap.run()
