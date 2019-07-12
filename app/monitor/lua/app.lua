-- local path = require('path')
-- local fs = require('fs')
-- local app       = require('app')

-- local exports = {}



-- app.name = 'monitor'



-- function exports.start()

--     setInterval(1000,function()
--         console.log(os.getenv("USER"))
--         local path =  "/usr/share/udhcpc/udhcp.txt"
--         local source = fs.openSync(path, 'r', 438)
--         local result = fs.readSync(source)
--         fs.closeSync(source)
--         local ipPatten = "ip:%d+.%d+.%d+.%d+"
--         local routerPatten = "router:%d+.%d+.%d+.%d+"
--         local addressPatten = "%d+.%d+.%d+.%d+"
--         local ip
--         local router
--         local ipChunk = string.match(result,ipPatten)
--         local routerChunk = string.match(result,routerPatten)
--         if(ipChunk) then
            
--             ip = string.match(ipChunk,addressPatten)
--             console.log("ip:"..ip)
--         end
            
--         if(routerChunk) then
--             router = string.match(routerChunk,addressPatten)
--             console.log("router:"..router)
--         end
       
--    end)
-- end

-- exports.start()

-- app(exports)



local function dhcpMonitor()

    if(arg[1]) then
        console.log("ip:"..arg[1])
        -- local t= io.popen('ifconfig eth0 192.168.8.104')

    end
       
end

dhcpMonitor()
