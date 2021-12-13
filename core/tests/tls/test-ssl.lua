local tls = require('lmbedtls.tls')

local MBEDTLS_ERR_SSL_WANT_READ   = -0x6900 -- 26800 /**< Connection requires a read call. */
local MBEDTLS_ERR_SSL_WANT_WRITE  = -0x6880 -- 26752

local function test()
	local ssl = tls.new()

	local lastdata = ''
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

	local HOST = "cn.bing.com"
	local PORT = 443

	console.log('connect', ssl:connect(HOST, PORT))
	console.log('config', ssl:config(HOST, 1, callback))

	local ret = ssl:handshake()
	console.log('handshake', string.format("%d", ret)) -- 0x7200

	local function sendRequest(ssl)
		local message = "GET / HTTP/1.0\r\nHost: cn.bing.com\r\n\r\n"
		console.log('write', ssl:write(message))

		for i = 1, 100 do
			ssl:read()
			-- console.log('read', )
		end
	end

	sendRequest(ssl)
end

test()
setTimeout(5000, function() end)
