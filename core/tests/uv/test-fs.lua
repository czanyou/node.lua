local utils  = require('util')
local assert = require('assert')
local uv     = require('luv')

local tap = require('util/tap')
local test = tap.test

test("fs.read - sync", function (expect, uv)
	local fd = assert(uv.fs_open('run.lua', 'r', tonumber('644', 8)))
	--print('fd', fd)

	local stat = assert(uv.fs_fstat(fd))
	--print('stat.size', stat.size)

	local chunk = assert(uv.fs_read(fd, stat.size, 0))
	assert(#chunk == stat.size)
	assert(uv.fs_close(fd))

	console.log('chunk.length', #chunk)
end)

test("fs.read - async", function (expect, uv)
	uv.fs_open('run.lua', 'r', tonumber('644', 8), expect(function (err, fd)
		assert(not err, err)
		--print('fd', fd)
		uv.fs_fstat(fd, expect(function (err, stat)
			assert(not err, err)
			--print('stat.size', stat.size)
			uv.fs_read(fd, stat.size, 0, expect(function (err, chunk)
				assert(not err, err)
				console.log('chunk.length', #chunk)
				assert(#chunk == stat.size)
				uv.fs_close(fd, expect(function (err)
					assert(not err, err)
				end))
			end))
		end))
	end))
end)

test("fs.write - sync", function (expect, uv)
	local temp = uv.os_tmpdir() or '/tmp'

	local path = temp .. "/_test_"
	local fd = assert(uv.fs_open(path, "w", 438))
	uv.fs_write(fd, "Hello World\n", -1)
	uv.fs_write(fd, {"with\n", "more\n", "lines\n"}, -1)
	uv.fs_close(fd)

	local stat = assert(uv.fs_stat(path))
	assert.equal(stat.size, 28)

	uv.fs_unlink(path)

	console.log('path', path, stat.size)
end)

test("fs.stat - sync", function (expect, uv)
	local stat = assert(uv.fs_stat("run.lua"))
	assert(stat.size)
	console.log('stat.size', stat.size)
end)

test("fs.stat - async", function (expect, uv)
	assert(uv.fs_stat("run.lua", expect(function (err, stat)
		assert(not err, err)
		assert(stat.size)
		console.log('stat.size', stat.size)
	end)))
end)

test("fs.stat - sync error", function (expect, uv)
	local stat, err, code = uv.fs_stat("BAD_FILE!")
	console.log('error', code, err)
	assert(not stat)
	assert(err)
	assert(code == "ENOENT")
end)

test("fs.stat - async error", function (expect, uv)
	assert(uv.fs_stat("BAD_FILE@", expect(function (err, stat)
		console.log('error', err)
		assert(err)
		assert(not stat)
	end)))
end)

test("fs.scandir", function (expect, uv)
	local req = uv.fs_scandir('.')
	local function iter()
		return uv.fs_scandir_next(req)
	end

	local index = 0
	local found = false

	for name, type in iter do
		print(type, name)
		assert(name)

		if (name == 'test-fs.lua') then
			found = true
			assert.equal(type, 'file')
		end

		index = index + 1
	end

	assert(index > 1)
	assert(found, 'test-fs.lua not found!')
end)

test("fs.realpath", function (expect, uv)
	assert(uv.fs_realpath('.'))
	assert(uv.fs_realpath('.', expect(function (err, path)
		assert(not err, err)
		console.log('realpath', path)
	end)))
end)

test("read a file async in thread", function ()
	local await = utils.await
	local async_func = function(param)
		assert.equal('test', param)

		local err, fd = await(uv.fs_open, 'run.lua', 'r', tonumber('644', 8))
		assert(not err, err)

		local err, stat = await(uv.fs_fstat, fd)
		assert(not err, err)

		local err, chunk = await(uv.fs_read, fd, stat.size, 0);
		assert(not err, err)
		assert(#chunk == stat.size, #chunk)  

		local err = await(uv.fs_close, fd)
		assert(not err, err)

		return 0
	end

	utils.async(function(param)
		local result = async_func(param)

		assert.equal(result, 0)

	end, 'test')
end)

tap.run()

