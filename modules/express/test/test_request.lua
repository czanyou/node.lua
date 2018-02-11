local request = require('http/request')

local url = 'http://node.sae-sz2.com/'
request(url, function(error, response, body)
	print(error, response, body)
end)

local url = 'http://node.sae-sz.com/'
request(url, function(error, response, body)
	print(error, response, body)
end)

run_loop()
