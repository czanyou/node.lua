local ret, cipher  = pcall(require, 'lmbedtls.cipher')
local utils = require('util')

console.log(cipher)

local test = cipher.new(cipher.AES_128_ECB)
test:init(cipher.OP_ENCRYPT)
test:set_key("1234567890123456", cipher.OP_ENCRYPT)
test:set_iv("1234567890123456")
test:reset()

local ret, err = test:update("1234567890ABCDEF1234567890ABCDEF")
console.printBuffer(ret)

console.log(test)
console.log(test:get_name())
console.log(test:get_block_size())
console.log(test:get_cipher_mode())
console.log(test:get_iv_size())
console.log(test:get_type())
console.log(test:get_key_bit_len())
console.log(test:get_operation())

local test = cipher.new(cipher.AES_128_ECB)
test:init(cipher.OP_DECRYPT)
test:set_key("1234567890123456", cipher.OP_DECRYPT)
test:reset()

console.log(test)
console.log(test:get_name())
console.log(test:get_operation())

local raw, err = test:update(ret)
console.log(raw)




