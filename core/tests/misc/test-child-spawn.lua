local spawn = require('child_process').spawn

local net = require('net')
local uv = require('luv')

local tap = require('util/tap')
local test = tap.test

test("environment subprocess", function(expect)
	local child, options, onStdoutData, onExit, onStdoutEnd, data

	options = {
		env = { TEST1 = 1 }
	}

	data = ""

	if os.platform() == "win32" then
		child = spawn("cmd.exe", {"/C", "set"}, options)
	else
		child = spawn("env", {}, options)
	end

	function onStdoutData(chunk)
		-- console.log('stdout', chunk)
		data = data .. chunk
	end

	function onExit(code, signal)
		console.log("exit", code, signal)
		assert(code == 0)
		assert(signal == 0)
	end

	function onStdoutEnd()
		assert(data:find("TEST1=1"))
		console.log("end and found", data)
	end

	child.stdout:once("end", expect(onStdoutEnd))
	child.stdout:on("data", onStdoutData)

	child:on("exit", expect(onExit))
	child:on("close", expect(onExit))
end)

test("invalid command", function(expect)
	local child, onError

	-- disable on windows, bug in libuv
	--if os.platform() == 'win32' then return end

	function onError(err)
		console.log("error", err)
		assert(err)
	end

	child = spawn("skfjsldkfjskdfjdsklfj")
	child:on("error", expect(onError))
	child.stdout:on("error", expect(onError))
	child.stderr:on("error", expect(onError))
end)

test("invalid command verify exit callback", function(expect)
	local child, onExit, onClose

	-- disable on windows, bug in libuv
	--if os.platform() == 'win32' then return end

	function onExit(exitCode)
		console.log("exit", exitCode)
	end

	function onClose(exitCode)
		console.log("close", exitCode)
	end

	child = spawn("skfjsldkfjskdfjdsklfj")
	child:on("exit", expect(onExit))
	child:on("close", expect(onClose))
end)

test("process.env pairs", function()
	local key = "LUVIT_TEST_VARIABLE_1"
	local value = "TEST1"
	local iterate, found

	function iterate()
		for k, v in pairs(process.env) do
			--console.log(k, v)
			if k == key and v == value then
				found = true
			end
		end
	end

	-- set env
	process.env[key] = value
	found = false
	iterate()
	assert(found)

	-- clear env
	process.env[key] = nil
	found = false
	iterate()
	assert(process.env[key] == nil)
	assert(found == false)
end)

test("child process no stdin", function(expect)
	local child, options

	options = {
		stdio = {
			nil,
			net.Socket:new({handle = uv.new_pipe(false)}),
			net.Socket:new({handle = uv.new_pipe(false)})
		}
	}

	if os.platform() == "win32" then
		child = spawn("cmd.exe", {"/C", "set"}, options)
	else
		child = spawn("env", {}, options)
	end

	child.stdout:on("data", function(data)
		console.log("data", data)
	end)

	child:on("exit", expect(function(exitCode)
		console.log("exit", exitCode)
	end))

	child:on("close", expect(function(exitCode)
		console.log("close", exitCode)
	end))
end)

test("child process (no stdin, no stderr, stdout) with close", function(expect)
	local child, options

	options = {
		stdio = {
			nil,
			net.Socket:new({handle = uv.new_pipe(false)}),
			nil
		}
	}

	if os.platform() == "win32" then
		child = spawn("cmd.exe", {"/C", "set"}, options)
	else
		child = spawn("env", {}, options)
	end

	child.stdout:on("data", function(data)
		console.log("data", data)
	end)

	child:on("close", expect(function(exitCode)
		console.log("close", exitCode)
		assert(exitCode == 0)
	end))
end)

test("child process send", function(expect)
	local child, options

	options = {}

	if os.platform() == "win32" then
		child = spawn("cmd.exe", {"/C", "set"}, options)
	else
		child = spawn("cat", {}, options)
	end

	child:on("message", function(data)
		console.log("message", data)
	end)

	child.stdout:on("data", function(data)
		console.log("data", data)
		child:disconnect()
	end)

	child:on("close", function(exitCode)
		console.log("close", exitCode)
	end)

	child:send('dddd')
	child:send('eeee')
end)

tap.run()
