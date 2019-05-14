local json = require('json')
local conf = require('app/conf')

local data = [[
{
    "data": {    
        "device": {
            "write": {
                "peripherals": {
                    "camera": [
                        {
                            "did": "112233445599",
                            "url": "rtsp://192.168.1.64/live.mp4",
                            "username": "admin",
                            "password": "admin123456"
                        }
                    ]
                }
            }
        }
    }
}
]]

console.log(data)

local jsonData = json.parse(data)

console.log(jsonData, #jsonData)

local text = json.stringify(jsonData.data.device.write)

local profile = conf('test')
profile:set('test', jsonData.data.device.write)
console.log('output', profile:toString())

profile:commit()


local profile2 = conf('test')
local value = profile2:get('test');

print(json.stringify(value, nil, ' '))

