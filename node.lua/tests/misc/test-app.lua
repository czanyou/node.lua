local app 		= require('app')
local tap 	    = require("ext/tap")
local utils     = require('utils')
local assert    = require('assert')
local rpc    	= require('ext/rpc')

console.log(app)

tap(function(test)
    test("test rpc", function()
    	local server = nil
    	server = app.rpc('test', {
    		foo = function(self, ...) 
    			console.log(...) 
    			--console.log(server)

    			server:close()
    		end
    	})

    	rpc.call('test', 'foo', 100)
    end)

    test("assert not true", function()
    	
    end)

end)
