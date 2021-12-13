local pk   = require('lmbedtls.pk')
local rng  = require('lmbedtls.rng')

local utils 	= require('util')
local assert 	= require('assert')

local tap 	    = require('util/tap')
local util 	    = require('util')
local crypto    = require('crypto')

local test = tap.test

test("test crypto.parsePublicKeyFile", function()
    local filename = utils.dirname() .. "/rsa_public_key.pem"
	local publicKeyFile = pk.parsePublicKeyFile(filename)

	assert.equal(publicKeyFile:getBitLength(), 1024)
	assert.equal(publicKeyFile:getLength(), 128)
	assert.equal(publicKeyFile:getName(), 'RSA')
	assert.equal(publicKeyFile:getType(), 1)
end)

test("test crypto.parseKeyFile", function()
	local filename = utils.dirname() .. "/rsa_private_key.pem"
	local keyfile = pk.parseKeyFile(filename)

	assert.equal(keyfile:getBitLength(), 1024)
	assert.equal(keyfile:getLength(), 128)
	assert.equal(keyfile:getName(), 'RSA')
	assert.equal(keyfile:getType(), 1)
end)

test("test crypto.parseKeyFile", function()
	local rng_test = rng.new()

	local raspk = pk.new(pk.RSA)
	console.log(raspk)

	console.log(raspk:genKey(rng_test, 1024))

    --[[
	print(raspk:writeKeyPem())
	print(raspk:writePublicKeyPem())
    console.printBuffer(raspk:writeKeyDer())
    --]]

	console.log(raspk:getBitLength())
	console.log(raspk:getLength())
	console.log(raspk:getName())
    console.log(raspk:getType())

    local ret, err, raw
    ret, err = raspk:encrypt('test', rng_test)
	console.printBuffer(ret)

	raw, err = raspk:decrypt(ret, rng_test)
	console.log('raw', raw, err)

	ret, err = raspk:sign(0, 'test', rng_test)
	console.printBuffer(ret)

	raw, err = raspk:verify(0, 'test', ret)
	console.log('verify', raw, err)
end)

local publicKey =
[[
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCxGo4l9ULEZZn0kwH4KblqscAj
5u0cI6VmmqINFtbFFN59kcI0rPLE96Bd8SHhwVrSYwTpAUpTO0g5OyBOS+3HHAu1
vDr+N07/BbTX2EAAbm2l3wfusahurPMwZIRXaoWTX5V74vdF1JWEkwWEsp8MVYyd
sJjrDJpc74+0+/XuxwIDAQAB
-----END PUBLIC KEY-----
]]

test("test crypto.parsePublicKeyFile", function()
	local publicKeyFile = pk.parsePublicKey(publicKey)
    assert(publicKeyFile)
end)

tap.run()
