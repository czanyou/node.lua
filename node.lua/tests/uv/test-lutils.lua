local utils   = require('utils')
local lutils  = require('lutils')
local assert  = require('assert')
local tap     = require('ext/tap')
local fs      = require('fs')
local thread  = require('thread')

tap(function(test)

	test('lutils.hex_encode', function()
		local data = "888888"
		local hash = lutils.hex_encode(data)
		assert.equal(hash, '383838383838')

		local raw = lutils.hex_decode(hash)
		assert.equal(raw, '888888')

		assert.equal(lutils.hex_decode(''), nil)
		assert.equal(lutils.hex_encode(''), nil)

		local data = "\11\10\78\119\232\82\135\107"
		local hash = lutils.hex_encode(data)
		--assert.equal(hash, '383838383838')
		print('hash', hash)
	end)


  	test('lutils.md5', function()
  		local data = "888888"
		local hash = lutils.md5(data)

		local hex_hash = lutils.hex_encode(hash)
		assert.equal(hex_hash, '21218cca77804d2ba1922c33e0151105')

		--utils.printBuffer(hash)
  	end)

  	test('lutils.base64_encode', function()
		local data = "888888"
		local hash = lutils.base64_encode(data)
		assert.equal(hash, 'ODg4ODg4')

		local raw = lutils.base64_decode(hash)
		assert.equal(raw, '888888')

		assert.equal(lutils.base64_decode(''), nil)
		assert.equal(lutils.base64_encode(''), nil)

  	end)

	test('lutils.os_file_lock', function()
		local filename = '/tmp/lock'

		local fd1 = fs.openSync(filename, 'w+')
		print('fd1', fd1)

		if (not fd1) then
			return
		end

		local ret = lutils.os_file_lock(fd1, 'w')
		print('write1', ret)

		if (ret >= 0) then
			thread.sleep(1000 * 5)

			ret = lutils.os_file_lock(fd1, 'u')
			print('unlock', ret)
		end
	end)
end)
