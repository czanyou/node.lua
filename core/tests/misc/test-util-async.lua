local utils = require("util")
local fs = require("fs")
local assert = require("assert")

local await = utils.await

local tap = require("ext/tap")
local test = tap.test

test("test utils.await", function(expected)
	local test = "b"

	utils.async(function(...)
		--print(test, ...)

		local err, statInfo = await(fs.stat, "/")
		console.log(err, statInfo.size)
	end)
end)

test("test utils.await", function(expected)
	---------------------------------------

	local async_func = function(arg, callback)
		callback(arg * 10)
	end

	async_func(10, function(result)
		assert.equal(result, 100) -- result = 100

		async_func(result, function(result)
			assert.equal(result, 1000) -- result = 1000

			async_func(result, function(result)
				assert.equal(result, 10000) -- result = 10000
			end)
		end)
	end)

	---------------------------------------

	utils.async(function(param)
		local result = await(async_func, param)
		assert.equal(result, 100) -- 100

		result = await(async_func, result)
		assert.equal(result, 1000) -- 1000

		result = await(async_func, result)
		assert.equal(result, 10000) -- 10000
	end, 10)
end)

tap.run()
