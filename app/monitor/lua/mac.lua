
local app   = require('app')
local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local http  = require('http')
local json  = require('json')
local wot   = require('wot')




-- local function getMac()
--     local path = "/sys/class/net/eth0/address"
--     local did
--     local mac, err = fs.readFileSync(path)
 
--     console.log(mac)
--     for value in string.gmatch(mac, "(%s+):*") do
--         if(did) then
--             did = did..value
--         else
--             did = value
--         end
--     end
--     console.log(did)
         
      

-- end



local function setMac()
    local did = app.get('did')
    if(did) then
        mac = string.sub(did,1,2)..":"..string.sub(did,3,4)..":"..string.sub(did,5,6)..":"..string.sub(did,7,8)..":"..string.sub(did,9,10)..":"..string.sub(did,11,12)
        console.log(mac)
        local cmd = "ifconfig eth0 down"
        os.execute(cmd)
        cmd = "ifconfig eth0 hw ether "..mac
        os.execute(cmd)
        cmd = "ifconfig eth0 up"
        os.execute(cmd)
    end

end

setMac()