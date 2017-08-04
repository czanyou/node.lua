local fs 	= require('fs')
local path 	= require('path')

local bundle = require('zlib')
local lpm = require('ext/lpm')

return require('ext/tap')(function (test)

	test("Lua Package Manager Help", function (print, p, expect, uv)
		local lpm = lpm.PackageManager:new()
		lpm:help()
	end)

	test("Lua Package Manager Update", function (print, p, expect, uv)
		local lpm = lpm.PackageManager:new()
		--lpm:update()
	end)

	test("Lua Package Manager List", function (print, p, expect, uv)
		local lpm = lpm.PackageManager:new()
		lpm:list()
	end)

	test("Lua Package Manager Install", function (print, p, expect, uv)

	end)	

end)
