local formdata = require('express/formdata')
local FormData = formdata.FormData

local tap = require('util/tap')

local test = tap.test

test('test', function()

	local data = '------WebKitFormBoundarycezqTco6VlXfs9L1\r\nContent-Disposition: form-data; name="file"; filename="target"\r\nContent-Type: application/octet-stream\r\n\r\nhi3516a\n\r\n------WebKitFormBoundarycezqTco6VlXfs9L1--\r\n'

	local parser = FormData:new()

	parser:on('file', function(data)
		console.log('file', data)
	end)

	parser:on('header-name', function(data)
		console.log('header-name', data)
	end)

	parser:on('header-value', function(data)
		console.log('header-value', data)
	end)

	parser:on('feild-name', function(data)
		console.log('feild-name', data)
	end)

	parser:on('feild-value', function(data)
		console.log('feild-value', data)
	end)

	parser:processData(data)

end)

test('test', function()
	local function test()
		local form = FormData:new()
		form:on('file', function(data) 
			console.log('file', #data, data)
		end)
	
		--[[
		form:processData('------abcde\r\n')
		form:processData('\r\ndatadata\r\n\r\n')
		form:processData('------abcde\r\n')
		form:processData('\r\ngcdddddddddgc')
		form:processData('------abcde--')
		--]]
	
		-- [[
		form:processData('------abcde')
		form:processData('\r\n\r\n[filedata-')
		form:processData('filedata-\r\n\r\n------abcd')
		form:processData('\r\nfiledata\r\nfiledata-')
		form:processData('filedata]\r\n------abcde\r\n')
		form:processData('[header:data]\r\n')
		form:processData('Content-Disposition: form-data;name="pic"; filename="photo.jpg"\r\n\r\n[filedata')
		form:processData('\r\nfiledata]\r\n------abcde')
		form:processData('--')
		--]]
	
		local buffer = form.buffer
		--console.log('buffer', buffer:size(), buffer:toString())
	end
	
end)
