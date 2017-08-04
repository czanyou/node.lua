local utils = require('utils')
local lhttp_parser = require('lhttp_parser')
local assert = require('assert')


function decoder()
	local headers = nil
	local headerName = nil

	local options = {
		message_begin = function(...) 
			headers = {} 
		end,

		message_complete = function(...)
			
		end,

		url = function(url) 
			--request.url = url 
			console.log('url', url)
		end,

		header_field = function(name) 
			headerName = name 

			console.log('name', name)
		end,

		header_value = function(value)
			headers[headerName] = value 

			console.log('value', value)
		end,

		body = function(body) 
			console.log('body', body)

		end,

		headers_complete = function(meta) 
			console.log('meta', meta)
		end
	}

    local parser = lhttp_parser.new('both', options)

    return function(chunk)
        local ret = parser:execute(chunk, 0, #chunk)
        console.log(ret, 0, #chunk)
    end
end

return require('ext/tap')(function (test)


	--console.log(lhttp_parser)
	test("parse_url", function()

		local ret = lhttp_parser.parse_url("http://test.com/path?q=4#1984")
		--console.log(ret)
		assert.equal(ret.host, 		'test.com')
		assert.equal(ret.path, 		'/path')
		assert.equal(ret.query, 	'q=4')
		assert.equal(ret.schema, 	'http')
		assert.equal(ret.fragment, 	'1984')
	end)

	test("parse request", function()
		local request = nil
		local headers = nil
		local header_name = nil

		local data = {}

		local options = {
			message_begin 		= function(...) request = {}; headers = {} end,
			message_complete 	= function(...)
				request.headers = headers
				request.body    = table.concat(data)
			end,
			url 				= function(url) request.url = url end,
			header_field 		= function(name) header_name = name end,
			header_value 		= function(value) headers[header_name] = value end,
			body 				= function(body) table.insert(data, body) end,
			headers_complete 	= function(meta) request.method = meta.method end,
		}

		local parser = lhttp_parser.new('both', options)

		local message = 
		"GET http://192.168.1.1/path HTTP/1.1\r\nA:B\r\nContent-Length:4\r\n\r\n1234"

		local ret = parser:execute(message, 0, #message)
		--console.log(request)

		assert.equal(request.method, 'GET')
		assert.equal(request.body, '1234')
		assert.equal(request.url, 'http://192.168.1.1/path')
		assert.equal(request.headers["A"], 'B')

	end)

	test("parse response", function()
		local response = nil
		local headers = nil
		local header_name = nil

		local data = {}

		local options = {
			message_begin 		= function(...) response = {}; headers = {} end,
			message_complete 	= function(...) 
				response.headers = headers
				response.body    = table.concat(data)
			end,
			url 				= function(url) response.url = url end,
			header_field 		= function(name) header_name = name end,
			header_value 		= function(value) headers[header_name] = value end,
			body 				= function(body) table.insert(data, body) end,
			headers_complete 	= function(meta) response.status_code = meta.status_code end,
		}

		local parser = lhttp_parser.new('both', options)

		local message =  "HTTP/1.1 200 OK\r\nA:B\r\n"
		local ret = parser:execute(message, 0, #message)
		
		local message = "Content-Type:4\r\n\r\n1234"
		local ret = parser:execute(message, 0, #message)
		
		message = "66668888"
		parser:execute(message, 0, #message)

		parser:finish()
		--console.log(response)

		assert.equal(response.status_code, 200)
		assert.equal(response.body, '123466668888')
		assert.equal(response.headers["A"], 'B')
	end)

	test("parse chunked", function()
		local response = nil
		local headers = nil
		local header_name = nil

		local data = {}

		local options = {
			message_begin 		= function(...) response = {}; headers = {} end,
			message_complete 	= function(...) 
				response.headers = headers
				response.body    = table.concat(data)
			end,
			url 				= function(url) response.url = url end,
			header_field 		= function(name) header_name = name end,
			header_value 		= function(value) headers[header_name] = value end,
			body 				= function(body) 
				print('body', body)
				table.insert(data, body) 
			end,
			headers_complete 	= function(meta) response.status_code = meta.status_code 
				console.log(headers)
			end,
		}

		local parser = lhttp_parser.new('both', options)

		local message =  "HTTP/1.1 200 OK\r\nA:B\r\n"
		local ret = parser:execute(message, 0, #message)
		
		local message = "Transfer-Encoding: chunked\r\n"
		local ret = parser:execute(message, 0, #message)

		message = "Transfer-"
		parser:execute(message, 0, #message)

		message = "Type:  chunked\r\n\r\n"
		parser:execute(message, 0, #message)
		
		message = "4\r\n1234\r\n"
		parser:execute(message, 0, #message)

		message = "8\r\n6666"
		parser:execute(message, 0, #message)

		message = "8888\r\n"
		parser:execute(message, 0, #message)

		message = "0\r\n\r\n"
		parser:execute(message, 0, #message)

		parser:finish()


		assert.equal(response.status_code, 200)
		assert.equal(response.body, '123466668888')
		assert.equal(response.headers["A"], 'B')

		message =  "HTTP/1.1 200 OK\r\nA:B\r\n"
		parser:execute(message, 0, #message)
		
		message = "Transfer-Encoding: chunked\r\n"
		parser:execute(message, 0, #message)

		message = "Transfer-"
		parser:execute(message, 0, #message)

		message = "Type:  chunked\r\n\r\n"
		parser:execute(message, 0, #message)

		--parser:finish()
		--console.log(response)

	end)

	test("parse chunked response", function()
		local decode = decoder()

		local message =  "POST /foo HTTP/1.1\r\nHost: 127.0.0.1\r\nUser-Agent: lnode/http/1.2.3\r\nbar: cats\r\nContent-Length: 1048576\r\nTransfer-Encoding: chunked\r\nconnection: close\r\n\r\n"
		--message =  "HTTP/1.1 200 OK\r\nA:B\r\n\r\n"

		console.log(decode(message))

		--local message = "Transfer-Encoding: chunked\r\n\r\n"
		--console.log(decode(message))

		message = "4\r\n1234\r\n"
		console.log(decode(message))

		message = "8\r\n6666"
		console.log(decode(message))

		message = "8888\r\n"
		console.log(decode(message))

		message = "0\r\n\r\n"
		console.log(decode(message))
	end)

end)
