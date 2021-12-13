local rpc   = require('app/rpc')
local tap    = require('util/tap')

describe("test rpc - Lua Remote Call", function ()
	os.remove('test-rpc')

	local handler = {
		test = function( self, arg1, arg2, arg3 )
			-- console.log('args: ', arg1, arg2, arg3)

			assert(arg1 == 'a')
			assert(arg2 == 100)

			return 3.14
		end
	}

	local server = rpc.server('test-rpc', handler)

	console.time('test')
	local index = 1
	local sendRequest
	sendRequest = function()
		rpc.call('test-rpc', 'test', {'a', 100, index}, function(err, result)
			-- server:close()
			if (err) then
				console.log('error: ', err)
				return
			end

			--console.log('result: ', result)
			assert(result == 3.14)

			index = index + 1
			if (index < 1000) then
				setImmediate(sendRequest)
			else
				console.timeEnd('test')
				server:close()
			end
		end)
	end

	sendRequest()
end)

describe("test rpc - error response", function ()
	os.remove('test-rpc')

	local handler = {
		test = function( self, arg1, arg2, arg3 )
			error('test')
		end
	}

	local server = rpc.server('test-rpc', handler)

	console.time('test')
	local index = 1
	local sendRequest
	sendRequest = function()
		rpc.call('test-rpc', 'test', {'a', 100, index}, function(err, result)
			if (err) then
				console.log('error: ', err)
				server:close()
				return
			end
		end)
	end

	sendRequest()
end)

describe("test rpc - invalid request", function ()
	os.remove('test-rpc')

	local handler = {
		test = function( self, arg )
			return 100
		end
	}

	local server = rpc.server('test-rpc', handler)

	console.time('test')
	local index = 1

	local pipe = rpc.call('test-rpc', 'test', {'a', 100, index}, function(err, result)
		assert(err)
		if (err) then
			console.log('error: ', err)
			server:close()
			return
		end
	end)

	for i = 1, 1024 do
		pipe:write(string.rep('n', 1024))
	end
end)

describe("test rpc - invalid method", function ()
	os.remove('test-rpc')

	local handler = {
		test = function( self, arg )
			return 100
		end
	}

	local server = rpc.server('test-rpc', handler)

	console.time('test')
	local index = 1

	local pipe = rpc.call('test-rpc', 'find', {'a', 100, index}, function(err, result)
		assert(err)
		if (err) then
			console.log('error: ', err)
			server:close()

			assert(err.code, -32601)
			assert(err.message, 'Method not found')
			return
		end
	end)
end)
