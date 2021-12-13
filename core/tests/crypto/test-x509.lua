local rng = require('lmbedtls.rng')
local csr = require('lmbedtls.x509.csr')
local util = require('util')
local fs = require('fs')
local crypto = require('crypto')
local tap = require('util/tap')

console.log(rng)

local test = tap.test

test("test csr", function()
    local filename1 = util.dirname() .. "/cert_sha256.crt"
	local filedata1 = fs.readFileSync(filename1);
    console.log(csr, filedata1)

    console.log(csr.parse(filedata1))
    console.log(csr.parseFile(filename1))
end)

tap.run()
