local app = require('app')

-- 设置以太网口 MAC 地址
-- - 仅在系统初始化的时候调用这个方法

local function setMacAddress()
    local did = app.get('did')
    if (not did) then
        return
    end

    -- format MAC address string
    local mac = ''
    for i = 1, 11, 2 do
        if (i > 1) then
            mac = mac .. ':'
        end
        mac = mac .. (string.sub(did, i, i + 1) or '')
    end

    print('mac', mac)

    -- set mac address
    local cmd = "ifconfig eth0 down"
    os.execute(cmd)

    cmd = "ifconfig eth0 hw ether " .. mac
    os.execute(cmd)

    cmd = "ifconfig eth0 up"
    os.execute(cmd)
end

local function onSystemBoot()
    local boot = require('./boot')
    boot.onSystemBoot()
end

setMacAddress()
onSystemBoot()
