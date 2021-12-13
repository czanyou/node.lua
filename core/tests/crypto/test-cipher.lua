local cipher  = require('lmbedtls.cipher')
local assert = require('assert')
local tap = require('util/tap')
local test = tap.test

test('test - cipher', function()

    -- encrypt
    local aescipher = cipher.new(cipher.AES_128_ECB)
    aescipher:init(cipher.OP_ENCRYPT)
    aescipher:setKey("1234567890123456", cipher.OP_ENCRYPT)
    aescipher:setIv("1234567890123456")
    aescipher:reset()

    local ret = aescipher:update("1234567890ABCDEF1234567890ABCDEF")
    console.printBuffer(ret)

    console.log(aescipher)
    console.log("getName", aescipher:getName())
    console.log("getBlockSize", aescipher:getBlockSize())
    console.log("getCipherMode", aescipher:getCipherMode())
    console.log("getIvSize", aescipher:getIvSize())
    console.log("getType", aescipher:getType())
    console.log("getKeyBits", aescipher:getKeyBits())
    console.log("getOperation", aescipher:getOperation())

    -- decrypt
    aescipher = cipher.new(cipher.AES_128_ECB)
    aescipher:init(cipher.OP_DECRYPT)
    aescipher:setKey("1234567890123456", cipher.OP_DECRYPT)
    aescipher:reset()

    console.log(aescipher)
    console.log("getName", aescipher:getName())
    console.log("getOperation", aescipher:getOperation())

    local raw = aescipher:update(ret)
    console.log("raw", raw)

    assert.equal(raw, "1234567890ABCDEF1234567890ABCDEF")

end)

tap.run()
