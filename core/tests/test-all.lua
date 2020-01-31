local util  = require('util')
local path  = require('path')
local fs    = require('fs')
local tap   = require("ext/tap")

local function test_all(subdirs)
	local list = {}
	local dirname = util.dirname()

	for _, name in ipairs(subdirs) do
		local basePath = path.join(dirname, name)
		--print('basePath', basePath)

		local dirs = fs.readdirSync(basePath)
		for _, file in ipairs(dirs) do
			local match = file:match("^test%-(.*).lua$")
		    if match then
				--print('file', file)
				table.insert(list, path.join(basePath, file))
			end
		end
	end

	console.log(list)

	for _, file in ipairs(list) do
		local name = path.basename(file)
		tap.suite(name)

		process.chdir(path.dirname(file))
		dofile(file)
	end

	tap.run(true)
end

local subdirs = {"fs", "misc", "net", "stream", "uv"}
test_all(subdirs)
