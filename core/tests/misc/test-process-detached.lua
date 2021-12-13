local tap = require('util/tap')
local util = require('util')
local test = tap.test

local path = require('path')
local spawn = require('child_process').spawn

local __dirname = util.dirname()
console.log(process.execPath, __dirname)

test("process execute", function()
	local childPath = path.join(__dirname, "fixtures", "parent-process.lua")
	console.log(os.execute("lnode " .. childPath))
end)

test("process detached", function()
	local childPath = path.join(__dirname, "fixtures", "parent-process.lua")
	local persistentPid = -1

	if os.platform() == "win32" then
		return
	end

	local argv = process.argv
	local args =  { childPath }
	console.log('lnode', args)
	local child = spawn(process.execPath, args)
	
	child.stdout:on("data", function(data)
		console.log("data", data)
		persistentPid = tonumber(data)
	end)

	setTimeout(1000, function()
		local err = pcall(function()
			process.kill(child.pid)
		end)

		--process.kill(persistentPid)
	end)

	os.printAllHandles()

	setTimeout(900, function()
		child:send('message')
	end)

	child:on('exit', function(code)
		print('exit', code);
	end)

	child:on('close', function(code)
		print('close', code);
	end)

	--[[
process:on('exit', function()
	assert(persistentPid ~= -1)
	local err = pcall(function()
	process.kill(child.pid)
	end)
	process.kill(persistentPid)
end)
--]]
end)

--[[
test("process exec", function ()
	local childPath = path.join(__dirname, "fixtures", "parent-process.lua")
	local options = { timeout = 1000 }
	execFile(process.execPath, { childPath }, options, function(err, stdout, stderr)
		console.log('exec(err, stdout, stderr)', err, stdout, stderr)

		process.kill(0);
	end)
end)
--]]

tap.run()
