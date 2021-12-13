--[[

Copyright 2014-2015 The Luvit Authors. All Rights Reserved.
Copyright 2016-2020 The Node.lua Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]
--
local mbedtls_rng = require('lmbedtls.rng')
local mbedtls_cipher = require('lmbedtls.cipher')
local mbedtls_md = require('lmbedtls.md')
local mbedtls_pk = require('lmbedtls.pk')

local tls_rng = nil

local exports = {}

function exports.randomBytes(size, callback)
    if (not tls_rng) then
        tls_rng = mbedtls_rng.new()
    end

    local data = tls_rng:random(size)
    if callback then
        callback(nil, data)
    end

    return data
end

function exports.createCipher(algorithm, key, iv)
    if (type(algorithm) == 'string') then
        algorithm = string.upper(algorithm)
        algorithm = mbedtls_cipher[algorithm]
    end

    console.log('algorithm', algorithm)
    local cipher = mbedtls_cipher.new(algorithm)
    if (not cipher) then
        return
    end

    cipher:init(mbedtls_cipher.OP_ENCRYPT)
    cipher:setKey(key, mbedtls_cipher.OP_ENCRYPT)
    cipher:setIv(iv)
    cipher:reset()

    return cipher
end

function exports.createDecipher(algorithm, key)
    if (type(algorithm) == 'string') then
        algorithm = string.upper(algorithm)
        algorithm = mbedtls_cipher[algorithm]
    end

    local cipher = mbedtls_cipher.new(algorithm)

    cipher:init(mbedtls_cipher.OP_DECRYPT)
    cipher:setKey(key, mbedtls_cipher.OP_DECRYPT)
    cipher:reset()

    return cipher
end

function exports.createHmac(algorithm, secret)
    if (type(algorithm) == 'string') then
        algorithm = string.upper(algorithm)
        algorithm = mbedtls_md[algorithm]
    end

    local md = mbedtls_md.new(algorithm, secret)
    return md
end

function exports.createHash(algorithm)
    if (type(algorithm) == 'string') then
        algorithm = string.upper(algorithm)
        algorithm = mbedtls_md[algorithm]
    end

    local md = mbedtls_md.new(algorithm)
    return md
end

exports.md5 = mbedtls_md.md5
exports.sha1 = mbedtls_md.sha1
exports.sha256 = mbedtls_md.sha256
exports.sha512 = mbedtls_md.sha512

function exports.publicEncrypt(key, buffer)
    local publicKey, err = mbedtls_pk.parsePublicKey(key)
    if (err) then
        console.log(err)
        return nil, err
    end
	return publicKey:encrypt(buffer, tls_rng)
end

function exports.publicDecrypt(key, buffer)
    local publicKey, err = mbedtls_pk.parsePublicKey(key)
    if (err) then
        console.log(err)
        return nil, err
    end
	return publicKey:decrypt(buffer, tls_rng)
end

function exports.privateEncrypt(key, buffer)
    local privateKey, err = mbedtls_pk.parseKey(key)
    if (err) then
        console.log(err)
        return nil, err
    end
	return privateKey:encrypt(buffer, tls_rng)
end

function exports.privateDecrypt(key, buffer)
    local privateKey, err = mbedtls_pk.parseKey(key)
    if (err) then
        console.log(err)
        return nil, err
    end
	return privateKey:decrypt(buffer, tls_rng)
end

function exports.createPublicKey(algorithm)
	local publicKey = mbedtls_pk.new(algorithm)
	console.log(publicKey)

	console.log(publicKey:genKey(tls_rng, 1024))

	--print(publicKey:writeKeyPem())
	--print(publicKey:writePublicKeyPem())
end

function exports.getCiphers()
    local ciphers = {}
    for name, value in pairs(mbedtls_cipher) do
        if (type(value) == 'number') then
            name = string.lower(name)
            if (string.startsWith(name, 'op_')) then
                goto continue
            elseif (string.startsWith(name, 'mode_')) then
                goto continue
            elseif (string.startsWith(name, 'padding_')) then
                goto continue
            end

            table.insert(ciphers, name)
        end

        ::continue::
    end

    table.sort(ciphers)
    return ciphers
end

function exports.getHashes()
    local hashes = {}
    for name, value in pairs(mbedtls_md) do
        if (type(value) == 'number') then
            name = string.lower(name)
            table.insert(hashes, name)
        end
    end

    return hashes
end

function exports.sign(algorithm, data, key)
    local publicKey = mbedtls_pk.parseKey(key)
    -- local pk, err = mbedtls_pk.parsePublicKey(key)

    return publicKey:sign(0, data, tls_rng)
end

function exports.verify(algorithm, data, key, signature)
    local publicKey = mbedtls_pk.parsePublicKey(key)
    -- local pk, err = mbedtls_pk.parsePublicKey(key)

    return publicKey:verify(0, data, signature)
end

return exports
