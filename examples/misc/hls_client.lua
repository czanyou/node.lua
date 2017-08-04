local http 		= require('http')
local lreader 	= require("media/reader")

local test_url = "http://localhost:8001/live.ts"

http.get(test_url, function (res)
  print(res.statusCode)
  assert(res.statusCode == 200)
  assert(res.httpVersion == '1.1')

  local reader = lreader.open(function(sampleData, sampleTime, flags)
  	if (flags & lreader.FLAG_IS_AUDIO) ~= 0 then
  		if (flags & lreader.FLAG_IS_START) ~= 0 then
  			console.log(sampleTime, flags)
  			console.printBuffer(sampleData)
  		end
  	end
  end)  

  res:on('data', function (chunk)
      --p("ondata", {chunk=#chunk})

      --console.printBuffer(chunk)
      reader:read(chunk, 0)
  end)

  res:on('end', function ()
      p('stream ended')
  end)
end)