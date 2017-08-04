local md 		= require('lmbedtls.md')
local pk 		= require('lmbedtls.pk')
local rng 		= require('lmbedtls.rng')
local cipher 	= require('lmbedtls.cipher')
local csr 		= require('lmbedtls.x509.csr')

local utils = require('utils')

local KEY   = rng.new('gen key')

console.log(csr)

local value = md.md5('hello')
console.log(utils.bin2hex(value))

local value = md.sha256('hello')
console.log(utils.bin2hex(value))

local value = utils.md5('hello')
console.log(utils.bin2hex(value))


local p = pk.new(pk.RSA)
console.log(p)

local value = p:genkey(KEY, 256)
console.log(p:getname(), p:gettype(), p:getbitlen())

console.printBuffer(p:writekeyder())
console.printBuffer(p:writepubkeyder())


print(p:writekeypem())
print(p:writepubkeypem())
