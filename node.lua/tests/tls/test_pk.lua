local ret, pk   = pcall(require, 'lmbedtls.pk')
local ret, rng  = pcall(require, 'lmbedtls.rng')

local utils 	= require('utils')
local assert 	= require('assert')
local tap 		= require('ext/tap')
local fs 		= require('fs')

console.log(pk)

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
	console.log(filename)

	local filedata = fs.readFileSync(filename)
	local test2, err = pk.parse_public_key_file(filename)
	console.log(test2, err)

	console.log(test2:get_bit_len())
	console.log(test2:get_len())
	console.log(test2:get_name())
	console.log(test2:get_type())

	local filename = utils.dirname() .. "/rsa_private_key.pem"
	console.log(filename)

	local filedata = fs.readFileSync(filename)
	local test1, err = pk.parse_key_file(filename)
	console.log(test1, err)

	console.log(test1:get_bit_len())
	console.log(test1:get_len())
	console.log(test1:get_name())
	console.log(test1:get_type())

	local rng_test = rng.new()

	local ret, err = test2:encrypt('test', rng_test)
	console.printBuffer(ret)

	local raw, err = test1:decrypt(ret, rng_test)
	console.log('raw', raw, err)

else

	local rng_test = rng.new()

	local test = pk.new(pk.RSA)
	console.log(test)

	console.log(test:gen_key(rng_test, 1024))

	--print(test:write_key_pem())
	--print(test:write_public_key_pem())
	--console.printBuffer(test:write_key_der())

	console.log(test:get_bit_len())
	console.log(test:get_len())
	console.log(test:get_name())
	console.log(test:get_type())

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