local ret, md  	= pcall(require, 'lmbedtls.md')
local utils 	= require('utils')
local assert 	= require('assert')
local tap 		= require('ext/tap')

--console.log(md)
tap(function(test)
    test("test md", function()

    	assert.equal(utils.bin2hex(md.md5('test')), "098f6bcd4621d373cade4e832627b4f6")
    	assert.equal(utils.bin2hex(md.sha1('test')), "a94a8fe5ccb19ba61c4c0873d391e987982fbbd3")
    	assert.equal(utils.bin2hex(md.sha256('test')), "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08")
    	assert.equal(utils.bin2hex(md.sha512('test')), "ee26b0dd4af7e749aa1a8ee3c10ae9923f618980772e473f8819a5d4940e0db27ac185f8a0e1d5f84f88bc887fd67b143732c304cc5fa9ad8e6f57f50028a8ff")

		local test = md.new(md.MD5)
		--console.log(test)
		test:update('te')
		test:update('st')
    	assert.equal(utils.bin2hex(test:finish()), "098f6bcd4621d373cade4e832627b4f6")

    end)

    test("test hmac", function()
		local test = md.new(md.MD5, "test")
		--console.log(test)

		test:update('te')
		test:update('st')

		assert.equal(utils.bin2hex(test:finish()), "cd4b0dcbe0f4538b979fb73664f51abe")
	end)
end)