local config  = require('app/conf')




local exports = {}


local udhcpConfig = {}



local function dhcpMonitor()
    local profile 
    local function saveConfig(data)  
        config.load("network",function(ret,profile)
            profile:set("udhcp",data)
            -- for key,value in pairs (data) do
            --     profile:set(key,value)
            -- end
            profile:commit()
        end)
    end


    udhcpConfig.ip = os.getenv("ip")
    udhcpConfig.router = os.getenv("router")
    udhcpConfig.mask = os.getenv("subnet")

    saveConfig(udhcpConfig)

end

console.log("udhcpc test")
console.log(os.getenv("ip"))

console.log(os.getenv("subnet"))
dhcpMonitor()