local process 	= require('process')
local assert    = require('assert')

if (process.getgid) then
	console.log('gid', process.getgid())
	console.log('uid', process.getuid())
end

local tap = require("ext/tap")
local test = tap.test

test("test hrtime", function()
	assert.equal(type(process.hrtime()), 'number')
	assert(process.hrtime())
end)

test("test rootPath", function()
	assert.equal(type(process.rootPath), 'string')
	assert(process.rootPath)
	console.log(process.rootPath)
	console.log(process.now(), process.uptime())
end)

test("test argv", function()
	assert.equal(type(process.argv), 'table')
	assert(process.argv)
end)

test("test arch", function()
	assert.equal(type(process.arch()), 'string')
	assert(process.arch())
end)

test("test platform", function()
	assert.equal(type(process.platform()), 'string')
	assert(process.platform())
end)	

test("test cwd", function()
	assert.equal(type(process.cwd()), 'string')
	assert(process.cwd())
end)

test("test execPath", function()
	assert.equal(type(process.execPath), 'string')
	assert(process.execPath)
end)

test("test pid", function()
	assert.equal(type(process.pid), 'number')
	assert(process.pid)
end)

test("test version", function()
	assert.equal(type(process.version), 'string')
	assert(process.version)
end)

test("test versions", function()
	assert.equal(type(process.versions), 'table')
	assert(process.versions.lua)
	assert(process.versions.uv)
end)

test("test stdin", function()
	assert.equal(type(process.stdin), 'table')
end)

test("test stdout", function()
	assert.equal(type(process.stdout), 'table')
	process.stdout:write("test stdout\r\n")
end)

test("test stderr", function()
	assert.equal(type(process.stderr), 'table')
	process.stderr:write("test stderr\r\n")
end)	

test('signal usr1,usr2,hup', function(expect)
	local onHUP, onUSR1, onUSR2
	if os.platform() == 'win32' then 
		assert(true)

		return 
	end
	
	function onHUP()  print('sighup');  process:removeListener('sighup',  onHUP)  end
	function onUSR1() print('sigusr1'); process:removeListener('sigusr1', onUSR1) end
	function onUSR2() print('sigusr2'); process:removeListener('sigusr2', onUSR2) end

	process:on('sighup',  expect(onHUP))
	process:on('sigusr1', expect(onUSR1))
	process:on('sigusr2', expect(onUSR2))

	process.kill(process.pid, 'sighup')
	process.kill(process.pid, 'sigusr1')
	process.kill(process.pid, 'sigusr2')
end)
	
tap.run()
