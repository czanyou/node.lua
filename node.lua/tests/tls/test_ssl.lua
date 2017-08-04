local tls 		= require('lmbedtls.tls')
local utils 	= require('utils')
local lcrypto 	= require('tls/lcrypto')
local tap 		= require('ext/tap')
local net 		= require('net')
local uv 		= require('uv')

local data = ""


console.log('tls', tls)

local ssl = tls.new()

local lastdata = ''

console.log('ssl', ssl)

local function callback(data, len)
	if (len) then
		console.log('recv1', len, #lastdata)

		local ret = lastdata:sub(1, len)
		lastdata = lastdata:sub(len + 1)

		console.log('recv2', len, #ret, #lastdata)

		return ret

	else
		--console.log('send', #data)
		console.printBuffer(data)
	end
end

console.log('connect', ssl:connect("cn.bing.com", "443"))

console.log('config', ssl:config("cn.bing.com", callback))


local function onConnect()
	console.log('connect')
	tls_handshake()
end

local HOST = "cn.bing.com"
local PORT = 443


local ret = ssl:handshake()
console.log('handshake', string.format("%d", ret))


local message = "GET / HTTP/1.0\r\nHost: cn.bing.com\r\n\r\n"
console.log('write', ssl:write(message))

--console.log(ssl:read())

console.log('read')

setTimeout(5000, function() end)



