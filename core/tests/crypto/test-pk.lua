local pk   = require('lmbedtls.pk')
local rng  = require('lmbedtls.rng')

local utils 	= require('util')
local assert 	= require('assert')
-- console.log(pk)

local privateKey =
[[-----BEGIN RSA PRIVATE KEY-----
MIICXQIBAAKBgQCxGo4l9ULEZZn0kwH4KblqscAj5u0cI6VmmqINFtbFFN59kcI0
rPLE96Bd8SHhwVrSYwTpAUpTO0g5OyBOS+3HHAu1vDr+N07/BbTX2EAAbm2l3wfu
sahurPMwZIRXaoWTX5V74vdF1JWEkwWEsp8MVYydsJjrDJpc74+0+/XuxwIDAQAB
AoGARqReANwEhsw0Da85wN/7uoguKOPqvielyPhzHR94CWKaoKGsQlCeAVz4laAi
MKdsb7DZe4ttNyfVVia0aya0L+XsrAnD5PQzx4tRdQ5UWGqgrx8shy6MARYmaLTE
PkQFx/QfbfWMA8izCqA80Bp1GQqMKt1Uc16z9F7zB0rB7oECQQDp701NsaaUZZl6
Bx/XndlC7LwQj9zbjh7y+0JIS7XAJlFez7a5JUn7zQwqsoiHL4L4OWe8XP6MdwiH
PqzaiUOHAkEAwc78Bz1389WRd2qxBanBQQSVUEJ6iHYxgOtMamFIORhxzcbCKrsz
sIaM18ZGdQJFS+u2vM1nB5Uaxr84gqNKwQJAXuRLHzDouVldIDqzl+rXrmYJA07X
79d+hmGVSW4sk3z3lNX88K1HjXRncwpohy2mmrnucmHmf2PpebLauurjEQJBAJ/l
231Fs4+S5l81wTNA6NZxp5b+IgYwLYuFlhg2htXEWzBBCbUjmfPMLqtfRIYJB48p
vCxs8tIIrHzJCyCNBIECQQDVQe5nAY48l8Ss7drddBolVrmRXjyu+PhFRJYRPq/k
fycWIb3frI2FzlB1UpRHfm4X1bllGP8pfc/q0ZHYIMRF
-----END RSA PRIVATE KEY-----
]]

local publicKey =
[[-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCxGo4l9ULEZZn0kwH4KblqscAj
5u0cI6VmmqINFtbFFN59kcI0rPLE96Bd8SHhwVrSYwTpAUpTO0g5OyBOS+3HHAu1
vDr+N07/BbTX2EAAbm2l3wfusahurPMwZIRXaoWTX5V74vdF1JWEkwWEsp8MVYyd
sJjrDJpc74+0+/XuxwIDAQAB
-----END PUBLIC KEY-----
]]

-- [[

--publicKey = nil

if (publicKey) then
	local filename = utils.dirname() .. "/rsa_public_key.pem"
	local publicKeyFile = pk.parsePublicKeyFile(filename)

	assert.equal(publicKeyFile:getBitLength(), 1024)
	assert.equal(publicKeyFile:getLength(), 128)
	assert.equal(publicKeyFile:getName(), 'RSA')
	assert.equal(publicKeyFile:getType(), 1)

	filename = utils.dirname() .. "/rsa_private_key.pem"
	local keyfile = pk.parseKeyFile(filename)

	assert.equal(keyfile:getBitLength(), 1024)
	assert.equal(keyfile:getLength(), 128)
	assert.equal(keyfile:getName(), 'RSA')
	assert.equal(keyfile:getType(), 1)

	local rng_test = rng.new()

	local ret = publicKeyFile:encrypt('test', rng_test)
	-- console.printBuffer(ret)

	local raw = keyfile:decrypt(ret, rng_test)
	assert.equal(raw, 'test')

else
	local rng_test = rng.new()

	local test = pk.new(pk.RSA)
	console.log(test)

	console.log(test:genKey(rng_test, 1024))

	--print(test:writeKeyPem())
	--print(test:writePublicKeyPem())
	--console.printBuffer(test:writeKeyDer())

	console.log(test:getBitLength())
	console.log(test:getLength())
	console.log(test:getName())
	console.log(test:getType())

	local ret, err = test:encrypt('test', rng_test)
	console.printBuffer(ret)

	local raw, err = test:decrypt(ret, rng_test)
	console.log('raw', raw, err)


	local ret, err = test:sign(0, 'test', rng_test)
	console.printBuffer(ret)

	local raw, err = test:verify(0, 'test', ret)
	console.log('verify', raw, err)

end

--]]