local rng = require('lmbedtls.rng')
local utils = require('util')
local crypto = require('crypto')
local tap = require('util/tap')

console.log(rng)

local test = tap.test

test("test random", function()

    local rngTester = rng.new()
    console.log(rngTester)

    rngTester:setResistance(true)
    rngTester:setEntropyLength(32)
    rngTester:setReseedInterval(1000)
    rngTester:reseed("new seed")
    rngTester:update("seed")

    console.log(utils.hexEncode(rngTester:random(16)))
end)

test("test randomBytes", function()
    console.log(utils.hexEncode(crypto.randomBytes(16)))
end)

tap.run()
