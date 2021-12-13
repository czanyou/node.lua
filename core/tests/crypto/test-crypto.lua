local tap 	    = require('util/tap')
local util 	    = require('util')
local assert    = require('assert')
local crypto    = require('crypto')
local fs        = require('fs')

local test = tap.test

test("test crypto.getHashes", function()
	console.log(table.concat(crypto.getHashes(), ','))
	-- ripemd160,md5,md4,sha256,sha1,sha512,sha224,md2,sha384

	assert.equal(util.hexEncode(crypto.md5('test')), '098f6bcd4621d373cade4e832627b4f6')
	assert.equal(util.hexEncode(crypto.sha1('test')), 'a94a8fe5ccb19ba61c4c0873d391e987982fbbd3')
	assert.equal(util.hexEncode(crypto.sha256('test')), '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08')
	assert.equal(util.hexEncode(crypto.sha512('test')), 'ee26b0dd4af7e749aa1a8ee3c10ae9923f618980772e473f8819a5d4940e0db27ac185f8a0e1d5f84f88bc887fd67b143732c304cc5fa9ad8e6f57f50028a8ff')
end)

test("test crypto.createHash", function()
	local hash = crypto.createHash('md5')
	hash:update('tes')
	hash:update('t')
	assert.equal(util.hexEncode(hash:finish()), '098f6bcd4621d373cade4e832627b4f6')
end)

test("test crypto.createHmac", function()
	local hash = crypto.createHmac('md5', 'test')
	hash:update('test')
	assert.equal(util.hexEncode(hash:finish()), 'cd4b0dcbe0f4538b979fb73664f51abe')

	hash = crypto.createHmac('sha1', 'test')
	hash:update('test')
	assert.equal(util.hexEncode(hash:finish()), '0c94515c15e5095b8a87a50ba0df3bf38ed05fe6')

	hash = crypto.createHmac('sha256', 'test')
	hash:update('test')
	assert.equal(util.hexEncode(hash:finish()), '88cd2108b5347d973cf39cdf9053d7dd42704876d8c9a9bd8e2d168259d3ddf7')
end)

test("test crypto.randomBytes", function()
	console.log(util.hexEncode(crypto.randomBytes(32)))
end)

test("test crypto.getCiphers", function()
	console.log(table.concat(crypto.getCiphers(), ','))

	-- aes_128_cbc,aes_128_ccm,aes_128_cfb128,aes_128_ctr,aes_128_ecb,aes_128_gcm,aes_192_cbc,aes_192_ccm,aes_192_cfb128,aes_192_ctr,aes_192_ecb,aes_192_gcm,aes_256_cbc,aes_256_ccm,aes_256_cfb128,aes_256_ctr,aes_256_ecb,aes_256_gcm,arc4_128,
	-- blowfish_cbc,blowfish_cfb64,blowfish_ctr,blowfish_ecb,
	-- camellia_128_cbc,camellia_128_ccm,camellia_128_cfb128,camellia_128_ctr,camellia_128_ecb,camellia_128_gcm,camellia_192_cbc,camellia_192_ccm,camellia_192_cfb128,camellia_192_ctr,camellia_192_ecb,camellia_192_gcm,camellia_256_cbc,camellia_256_ccm,camellia_256_cfb128,camellia_256_ctr,camellia_256_ecb,camellia_256_gcm,
	-- des_cbc,des_ecb,des_ede3_cbc,des_ede3_ecb,des_ede_cbc,des_ede_ecb
end)

test("test crypto.createCipher", function()
	local cipher = crypto.createCipher('aes_128_ecb', '1234567890123456', '1234567890123456')
	local ret = cipher:update('1234567890ABCDEF1234567890ABCDEF')
	console.log(ret)
	console.log("getName", cipher:getName())
	console.log("getOperation", cipher:getOperation())

	assert.equal(util.hexEncode(ret), 'e8394a9271f42403ecc92d33d44847a0e8394a9271f42403ecc92d33d44847a0')
end)

test("test crypto.createDecipher", function()
	local decipher = crypto.createDecipher('aes_128_ecb', '1234567890123456')
	console.log("getName", decipher:getName())
	console.log("getOperation", decipher:getOperation())
	local data = util.hexDecode('e8394a9271f42403ecc92d33d44847a0e8394a9271f42403ecc92d33d44847a0')
	local ret = decipher:update(data)

	assert.equal(ret, '1234567890ABCDEF1234567890ABCDEF')
end)

test("test crypto.sign", function()
	local filename2 = util.dirname() .. "/rsa_private_key.pem"
	local filedata2 = fs.readFileSync(filename2);
	local ret, err = crypto.sign('rsa', 'test', filedata2)
	console.log(util.base64Encode(ret), err)

	local filename1 = util.dirname() .. "/rsa_public_key.pem"
	local filedata1 = fs.readFileSync(filename1);
	ret, err = crypto.verify('rsa', 'test', filedata1, ret)
	console.log(ret, err)

	assert(ret)
end)

test("test crypto.publicEncrypt1", function()
	local filename1 = util.dirname() .. "/rsa_public_key.pem"
	local filedata1 = fs.readFileSync(filename1);
	local ret = crypto.publicEncrypt(filedata1, 'test')
	console.log(util.base64Encode(ret))

	local filename2 = util.dirname() .. "/rsa_private_key.pem"
	local filedata2 = fs.readFileSync(filename2);
	local raw = crypto.privateDecrypt(filedata2, ret)
	console.log(raw)

	assert.equal(raw, 'test')
end)

tap.run()
