local formdata = require('express/formdata')

local data = '------WebKitFormBoundarycezqTco6VlXfs9L1\r\nContent-Disposition: form-data; name="file"; filename="target"\r\nContent-Type: application/octet-stream\r\n\r\nhi3516a\n\r\n------WebKitFormBoundarycezqTco6VlXfs9L1--\r\n'

local FormData = formdata.FormData
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
