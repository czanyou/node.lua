local request = require('http/request')

local url = 'http://node.sz.com/'
request(url, function(error, response, body)
	print(error, response, body)
end)

local url = 'http://node.sz.com/'
request(url, function(error, response, body)
	print(error, response, body)
end)
