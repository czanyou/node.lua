local tls 		= require('lmbedtls.tls')
local utils 	= require('util')
local lcrypto 	= require('tls/lcrypto')
local tap 		= require('ext/tap')
local net 		= require('net')
local uv 		= require('luv')

local data = ""

local MBEDTLS_ERR_SSL_WANT_READ   = -0x6900 -- 26800 /**< Connection requires a read call. */
local MBEDTLS_ERR_SSL_WANT_WRITE  = -0x6880 -- 26752


console.log('tls', tls)

local ssl = tls.new()

local lastdata = ''

console.log('ssl', ssl)

local index = 1

local function callback(data, len)

	if (len) then
		console.log('callback recv', len, #lastdata)

		return MBEDTLS_ERR_SSL_WANT_READ, "test"

	else
		console.log('send', #data, index)
		index = index + 1

		console.log(data)
		console.printBuffer(data)

		local len = #data

		return len
	end
end

console.log('connect', ssl:connect("cn.bing.com", "443"))
console.log('config', ssl:config("cn.bing.com", 1, callback))


local function onConnect()
	console.log('connect')
	-- tls_handshake()
end

local HOST = "cn.bing.com"
local PORT = 443


local ret = ssl:handshake()
console.log('handshake', string.format("%d", ret)) -- 0x7200


local function sendRequest(ssl)
	local message = "GET / HTTP/1.0\r\nHost: cn.bing.com\r\n\r\n"
	console.log('write', ssl:write(message))

	console.log(ssl:read())
	console.log(ssl:read())
end

sendRequest(ssl)

--console.log('read')

setTimeout(5000, function() end)



