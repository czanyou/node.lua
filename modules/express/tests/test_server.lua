local path 	 	= require('path')
local process 	= require('process')
local express 	= require('express')

local root = path.join(process.cwd(), "../lua/www")
--print('root', root)

local app = express({root=root})

app:post('/test', function(request, response)
    console.log('/upload', request, response)

    print('body', request.body)

    local result = { ret = 0 }
    response:json(result)
end)

app:listen(8088)

--[[
body = { AlarmInfoPlate = {
    channel = 0,
    deviceName = 'default',
    ipaddr = '192.168.1.102',
    result = { PlateResult = {
        bright = 0,
        carBright = 0,
        carColor = 0,
        colorType = 1,
        colorValue = 0,
        confidence = 84,
        direction = 1,
        imagePath = '',
        license = '警A1TK98',
        location = { RECT = {
            bottom = 628,
            left = 572,
            right = 1269,
            top = 1104
          } },
        timeStamp = { Timeval = { sec = 1577710602, usec = 0 } },
        timeUsed = 0,
        triggerType = 2,
        type = 1
      } },
    serialno = 'ceb80c847d600943'
  } },

--]]

