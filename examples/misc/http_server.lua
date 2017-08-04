local express 	= require('express')
local path      = require('path')
local utils     = require('utils')
local json      = require('json')

local querystring = require('querystring')

-- 演示 express 的用法，实现一个迷你 WEB 服务器

local function main()
	local root = path.dirname(process.cwd())
	local app  = express({ root = root })

	app:get("/test", function(request, response)
	    local reason = "test..."
	  	response:send(reason)
	end)

	app:get("/error", function(request, response)
	  	response:sendStatus(404)
	end)

	app:get("/json", function(request, response)
		local data = { name="Lucy", age=12}
	  	response:json(data)
	end)

	app:get("/query", function(request, response)
	  	response:json(request.query)
	end)

	app:get("/url", function(request, response)
	  	response:json(request.uri)
	end)	

	app:post("/post", function(request, response)
		--console.log(request)

		console.log('body', request.body)
		response:json(request.body)
	end)

	app:get("/form", function(request, response)
		local html = [[
		<h1>test post</h1>
		<hr/>
		<form method="POST" action="/post"><ul>
			<li><input name="test" value="888"/></li>
			<li><input name="value" value="888"/></li>
			<li><input type="submit" name="submit" value="Submit"/></li>
		</ul></form>

		]]
	  	response:send(html)
	end)

	app:get("/", function(request, response)
		local html = [[
		<h1>test express</h1>
		<hr/>
		<ul>
			<li><a href="/test">test send</a></li>
			<li><a href="/json">test json</a></li>
			<li><a href="/README.md">test static file</a></li>
			<li><a href="/examples">test file list</a></li>
			<li><a href="/error">test sendStatus</a></li>
			<li><a href="/form">test post form</a></li>
			<li><a href="/url?q=test">test url</a></li>
			<li><a href="/query?a=b&foo=bar&test=123&c=">test query</a></li>
		</ul>

		]]
	  	response:send(html)
	end)

	app:listen(8000)

end

main()
