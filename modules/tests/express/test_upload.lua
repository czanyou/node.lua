local path 	 	= require('path')
local thread 	= require('thread')
local process 	= require('process')
local express 	= require('express')
local conf  	= require('ext/conf')
local request 	= require('http/request')

local root = path.join(process.cwd(), "../lua/www")
--print('root', root)

local app = express({root=root})

app:post('/upload', function(request, response)
    print('test upload')
    --console.log('/upload', request, response)

    print('body', request.body)

    local result = { ret = 0 }
    response:json(result)
end)

app:listen(8090)

setTimeout(100, function()
    local url = 'http://localhost:8090/upload'
    local options = {}
    options.data = "12345678"
    request.post(url, options, function(err, response, body)
        console.log(err, response.statusCode, body)
    end)
end)
