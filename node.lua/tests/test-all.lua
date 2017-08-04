local utils = require('utils')
local path  = require('path')
local fs    = require('fs')
local tap   = require("ext/tap")

function function_name( ... )
	local req = uv.fs_scandir(cwd)

	console.log(cwd, req)

	repeat
	    local name = uv.fs_scandir_next(req)
	    if not name then
	        tap(true) -- run the tests!
	        break
	    end

	    local match = name:match("^test%-(.*).lua$")
	    if match then
	        tap(match)
	        require("test-" .. match)
	    end

	until not name

end


function test_all(subdirs)
	local list = {}
	local dirname = utils.dirname()

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

		tap(file)
		process.chdir(path.dirname(file))
		dofile(file)
	end

	tap(true)

end


local subdirs = {"fs", "misc", 'uv'}
test_all({'uv'})
