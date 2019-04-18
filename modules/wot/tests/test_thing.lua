local wot = require('wot')
local gateway = require('wot/gateway')

--console.log(wot)

local discover = wot.discover()
--console.log(discover)

discover:on('thing', function(thing)
    console.log('discover', thing)
end)

--console.log(server)
gateway:expose()

local url = "http://tour.beaconice.cn/directory"
wot:register(url, gateway)
