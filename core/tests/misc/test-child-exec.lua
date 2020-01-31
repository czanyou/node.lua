local exec  = require('child_process').exec
local execFile  = require('child_process').execFile

local tap = require('ext/tap')
local test = tap.test

test("exec", function ()
	local options = {}
	exec('pwd', options, function(err, stdout, stderr)
		console.log('exec(err, stdout, stderr)', err, stdout, stderr)
	end)
end)

test("execFile", function ()
	local options = {}
	execFile('echo', { 'test' }, options, function(err, stdout, stderr)
		console.log('exec(err, stdout, stderr)', err, stdout, stderr)
	end)
end)

tap.run()
