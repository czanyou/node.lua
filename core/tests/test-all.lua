local util  = require('util')
local path  = require('path')
local fs    = require('fs')
local tap   = require('util/tap')

local function test_all(subdirs)
	local list = {}
	local dirname = util.dirname()
	console.log('dirname', dirname)

	for _, name in ipairs(subdirs) do
		local basePath = path.join(dirname, name)
		local dirs = fs.readdirSync(basePath)
		for _, file in ipairs(dirs) do
		    if file:match("^test%-(.*).lua$") then
				table.insert(list, path.join(basePath, file))
			end
		end
	end

	for _, file in ipairs(list) do
		local name = path.basename(file)
		tap.suite(name)

		dirname = path.dirname(file)
		console.log('dirname', dirname)
		process.chdir(dirname)
		dofile(file)
	end

	tap.run(true)
end

local subdirs = {"crypto", "fs", "http", "misc", "net", "stream", "tls", "uv"}

test_all(subdirs)
