local fs 	= require('fs')
local path 	= require('path')

local bundle = require('zlib')

return require('ext/tap')(function (test)

	test("build a bundle sync", function (print, p, expect, uv)
		local cwd = process.cwd()
		print(cwd)

		-- bundle output
		local basePath = path.join(cwd, '../../build/tmp')
		fs.mkdirSync(basePath)

		local target = path.join(basePath, 'test.zip')
		os.remove(target)

		-- bundle source
		local basePath = path.join(cwd, '../../build/tmp/bundle')
		fs.mkdirSync(basePath)

		local filename1 = path.join(basePath, 'test1.lua')
		os.remove(filename1)

		local test1 = "print('test123456789')"
		fs.writeFileSync(filename1, test1)

		local filename2 = path.join(basePath, 'test2.lua')
		os.remove(filename2)

		local test2 = "print('abcd123456789!')"
		fs.writeFileSync(filename2, test2)

		-- build
		local builder = bundle.BundleBuilder:new(basePath, target)
		builder:build()

	end)

end)