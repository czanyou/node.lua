--[[

Copyright 2014 The Luvit Authors. All Rights Reserved.

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
local tap = require('util/tap')
local test = tap.test

local fs = require('fs')
local dirname = require('util').dirname()

local module = {}
module.path = dirname

test("readfile with callbacks", function (expect)
	local path = dirname .. "/fixtures/x.txt"
	fs.open(path, "r", expect(function (err, fd)
		assert(not err, err)
		--console.log{fd=fd}

		fs.fstat(fd, expect(function (err, stat)
			assert(not err, err)
			--console.log(stat)

			fs.read(fd, stat.size, expect(function (err, data)
				assert(not err, err)
				assert(#data == stat.size)
				console.log({chunk=#data, size=stat.size})

				fs.close(fd, expect(function (err)
					assert(not err, err)
				end))
			end))
		end))
	end))
end)

test("readfile sync", function ()
	local path = dirname .. "/fixtures/x.txt"
	local fd = assert(fs.openSync(path))
	--console.log{fd=fd}
	local stat = assert(fs.fstatSync(fd))
	--console.log(stat)
	local chunk = assert(fs.readSync(fd, stat.size))
	assert(stat.size == #chunk)
	console.log({chunk=#chunk, size=stat.size})
	fs.closeSync(fd)
end)

test("readfile coroutine", function (expect)
	local finish = expect(function () end)
	coroutine.wrap(function ()
		fs = fs.wrap()
		local thread = coroutine.running()
		--console.log{thread=thread}
		local path = dirname .. "/fixtures/x.txt"
		local fd = assert(fs.open(path, "r", thread))
		--console.log{fd=fd}
		local stat = assert(fs.fstat(fd, thread))
		--console.log(stat)
		local chunk = assert(fs.read(fd, stat.size, thread))
		console.log{chunk=#chunk, size=stat.size}
		assert(fs.close(fd, thread))
		finish()
	end)()
end)

test("file not found", function (expect)
	fs.stat("bad-path", expect(function (err, stat)
		console.log{err=err,stat=stat}
		assert(not stat)
		assert(string.match(err, "^ENOENT:"))
	end))
end)

test("optional args", function (expect)
	fs.open("bad-path", "r", tonumber("644", 8), expect(function (err)
	  	assert(string.match(err, "^ENOENT:"))
	end))

	fs.open("bad-path", "r", expect(function (err)
	  	assert(string.match(err, "^ENOENT:"))
	end))

	fs.open("bad-path", expect(function (err)
	  	assert(string.match(err, "^ENOENT:"))
	end))

	local _, err
	_, err = fs.openSync("bad-path", "r", tonumber("644", 8))
	assert(string.match(err, "^ENOENT:"))
	_, err = fs.openSync("bad-path", "r")
	assert(string.match(err, "^ENOENT:"))
	_, err = fs.openSync("bad-path")
	assert(string.match(err, "^ENOENT:"))
end)

test("readdir", function (expect)
	fs.readdir(dirname, expect(function (err, files)
		assert(not err, err)
		--console.log(files)
		assert(type(files) == 'table')
		assert(type(files[1] == 'string'))

		console.log('scandir count:', #files)
	end))
end)

test("readdir sync", function ()
	local files = assert(fs.readdirSync(dirname))
	--console.log(files)
	assert(type(files) == 'table')
	assert(type(files[1] == 'string'))
	console.log('scandir count:', #files)
end)

test("scandir callback", function (expect)
	fs.scandir(dirname, expect(function (err, it)
		assert(not err, err)
		local count = 0
		for k, v in it do
			--console.log{name=k,type=v}
			count = count + 1
		end
		console.log('scandir count:', count)
	end))
end)

test("scandir coroutine", function (expect)
	local done = expect(function () end)
	coroutine.wrap(function ()
		fs = fs.wrap()
		local thread = coroutine.running()
		local count = 0
		for k,v in fs.scandir(dirname, thread) do
			--console.log{name=k,type=v}
			count = count + 1
		end
		console.log('scandir count:', count)
		done()
	end)()
end)

test("scandir sync", function ()
	local count = 0
	for k,v in fs.scandirSync(dirname) do
	  	--console.log{name=k,type=v}
	  	count = count + 1
	end

	console.log('scandir count:', count)
end)

test('access', function (expect)
	local left = 3
	local result = {}
	local done = expect(function ()
		--console.log(result)
		assert(type(result.read) == "boolean")
		assert(type(result.write) == "boolean")
		assert(type(result.execute) == "boolean")
	end)

	fs.access(module.path, "r", expect(function (err, ok)
		assert(not err, err)
		result.read = ok
		left = left - 1
		if left == 0 then done() end
	end))
	
	fs.access(module.path, "w", expect(function (err, ok)
		assert(not err, err)
		result.write = ok
		left = left - 1
		if left == 0 then done() end
	end))

	fs.access(module.path, "x", expect(function (err, ok)
		assert(not err, err)
		result.execute = ok
		left = left - 1
		if left == 0 then done() end
	end))
end)

test('access coroutine', function ()
	coroutine.wrap(function ()
		fs = fs.wrap()
		local thread = coroutine.running()
		local result = {
			read = fs.access(module.path, "r", thread),
			write = fs.access(module.path, "w", thread),
			execute = fs.access(module.path, "x", thread),
		}
		--console.log(result)
		assert(type(result.read) == "boolean")
		assert(type(result.write) == "boolean")
		assert(type(result.execute) == "boolean")
	end)()
end)

test('access sync', function ()
	local result = {
		read = fs.accessSync(module.path, "r"),
		write = fs.accessSync(module.path, "w"),
		execute = fs.accessSync(module.path, "x"),
	}

	--console.log(result)
	assert(type(result.read) == "boolean")
	assert(type(result.write) == "boolean")
	assert(type(result.execute) == "boolean")
end)

test("readfile helper sync", function ()
	local path = dirname .. "/fixtures/x.txt"
	local data = fs.readFileSync(path)
	assert(#data > 0)
end)

test("readfile helper callback", function (expect)
	local path = dirname .. "/fixtures/x.txt"
	fs.readFile(path, expect(function (err, data)
		assert(not err, err)
		assert(#data > 0)
	end))
end)

test("readfile helper coroutine", function (expect)
	coroutine.wrap(expect(function ()
		fs = fs.wrap()
		local thread = coroutine.running()
		local path = dirname .. "/fixtures/x.txt"
		local data = fs.readFile(path, thread)
		assert(#data > 0)
	end))()
end)

tap.run()

