local exec  = require('child_process').exec

require('ext/tap')(function (test)

    test("exec", function ()

    	local options = {}
    	exec('cd', options, function(err, stdout, stderr)
    		--console.logBuffer(stdout)
    		console.log('err', err)
    		print('stdout', stdout, stderr)
    	end)
    end)
end)