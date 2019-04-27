local md 		= require('lmbedtls.md')
local pk 		= require('lmbedtls.pk')
local rng 		= require('lmbedtls.rng')
local cipher 	= require('lmbedtls.cipher')
local csr 		= require('lmbedtls.x509.csr')

local utils = require('util')

local KEY   = rng.new('gen key')

local value = md.md5('hello')
console.log('md5', utils.bin2hex(value))

local value = md.sha256('hello')
console.log('sha256', utils.bin2hex(value))

local value = utils.md5('hello')
console.log('md5', utils.bin2hex(value))

--console.log('pk', pk)
console.log('RSA', pk.RSA)

local p = pk.new(pk.RSA)
console.log('pk', p)

--local value = p:genkey(KEY, 256)
--console.log(p:getname(), p:gettype(), p:getbitlen())

--console.printBuffer(p:writekeyder())
--console.printBuffer(p:writepubkeyder())


--print(p:writekeypem())
--print(p:writepubkeypem())
