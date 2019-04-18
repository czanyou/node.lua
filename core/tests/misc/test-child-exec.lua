local exec  = require('child_process').exec

local tap = require('ext/tap')
local test = tap.test

test("exec", function ()

	local options = {}
	exec('cd', options, function(err, stdout, stderr)
		--console.logBuffer(stdout)
		console.log('err', err)
		print('stdout', stdout, stderr)
	end)
end)

tap.run()
