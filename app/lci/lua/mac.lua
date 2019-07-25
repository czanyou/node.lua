local app = require('app')

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
    if (not did) then
        return
    end

    local mac = ''
    for i = 1, 11, 2 do
        if (i > 1) then
            mac = mac .. ':'
        end
        mac = mac .. (string.sub(did, i, i + 1) or '')
    end

    print('mac', mac)

    local cmd = "ifconfig eth0 down"
    os.execute(cmd)

    cmd = "ifconfig eth0 hw ether " .. mac
    os.execute(cmd)

    cmd = "ifconfig eth0 up"
    os.execute(cmd)
end

setMac()
