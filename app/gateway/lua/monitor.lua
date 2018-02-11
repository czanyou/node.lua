local app       = require('app')
local utils     = require('utils')
local request   = require('http/request')
local fs        = require('fs')
local device    = require('sdl')
local json      = require('json')
local config    = require('ext/conf')
local rpc       = require('ext/rpc')
local URL       = 'http://nms.beaconice.cn:3000'
-------------------------------------------------------------------------------
-- exports

local cpu_info = {}
local configure = {}
local network_traffic_info = {}
local config_timestamp = 0
local res_lost_count = 0
local mac = ""
local target = ""
local version = ""
local memtotal = ""
local restart_beacon_program_state = false

function getFilename(url)
    local filename = string.reverse(url)
    local start = string.find(filename, '/', 0)
    start = start - 2
    filename = string.sub(url, string.len(url) - start, string.len(url))
    return filename
end

function getEth0Mac()
    -- local mac
    -- local network_info = os.networkInterfaces()
    -- console.log(network_info)
    -- if network_info == nil then return end
    -- for k, v in ipairs(network_info.eth0) do
    --     if v.family == 'inet' then 
    --         mac = string.upper(utils.bin2hex(v.mac))
    --     end
    -- end

    local data = fs.readFileSync('/sys/class/net/eth0/address')    
    -- local mac  = luaReomve(data,':')
    local mac = string.gsub(data, ':', '')
    -- mac = string.upper(string.sub(mac, 1, -2))
    mac = string.sub(mac, 1, -2)
    -- console.log(mac)
    return mac
end

function getTarget()
    local str = io.popen('uname -a', "r")
    str = str:read("*a")
    local uname_info_list = {}
    local i = 1;
    for w in string.gmatch(str,"%a+") do
        uname_info_list[i] = w
        i = i + 1
    end
    -- local system = uname_info_list[1];
    -- local system_type = uname_info_list[2];
    -- local system_version = uname_info_list[3];
    return uname_info_list[2];
end

function getCpuUsage()
    data = fs.readFileSync('/proc/stat')
    list = string.split(data, '\n')
    local d = string.gmatch(list[1],"%d+")

    local TotalCPUtime = 0;
    local x = {}
    local i = 1
    for w in d do
        TotalCPUtime = TotalCPUtime + w
        x[i] = w
        i = i +1
    end
    local TotalCPUusagetime = 0;
    TotalCPUusagetime = x[1]+x[2]+x[3]+x[6]+x[7]+x[8]+x[9]+x[10]
    local cpuUserPercent = TotalCPUusagetime/TotalCPUtime*100

    local delta_cpu_used_time = TotalCPUusagetime - cpu_info.used_time
    local delta_cpu_total_time = TotalCPUtime - cpu_info.total_time

    cpu_info.used_time = math.floor(TotalCPUusagetime) --record
    cpu_info.total_time = math.floor(TotalCPUtime) --record

    cpuUserPercent = math.floor(delta_cpu_used_time / delta_cpu_total_time * 100)
    return cpuUserPercent
end

function getMemTotal()
    local data = fs.readFileSync('/proc/meminfo')
    local list = string.split(data, 'kB\n')
    local MemTotal
    for w in string.gmatch(list[1],"%d+") do
        MemTotal = w
    end
    MemTotal = math.floor(MemTotal)
    return MemTotal
end

function getMemUsage()
    local data = fs.readFileSync('/proc/meminfo')
    local list = string.split(data, 'kB\n')
    local MemFree
    for w in string.gmatch(list[2],"%d+") do
        MemFree = w
    end
    local MemUsed = (memtotal-MemFree)
    MemUsed = math.floor(MemUsed)
    return MemUsed
end

function getRSSI()
    local data = fs.readFileSync('/proc/net/wireless')
    local i = 1
    local datas = {}
    for w in string.gmatch(data,"%d+") do
        datas[i] = w
        i = i + 1
    end
    return datas[5]
end

function getNetworkTraffic(interface)
    -- local data = fs.readFileSync('/proc/net/dev')
    -- for line in data.gmatch(data,"%s+") do
    --     console.log(line)
    -- end
    local tx, rx
    local tx_new, rx_new 
    local i = 1
    local datas = {}
    local file = io.open('/proc/net/dev')
    for line in file:lines() do
        -- console.log(line)
        if(string.find(line, interface)) then
            for w in string.gmatch(line,"%d+") do
                datas[i] = w
                i = i + 1
            end
            -- console.log(datas)
            rx_new = datas[2]
            tx_new = datas[10]
            break
        end
    end
    tx = tx_new - network_traffic_info.tx;
    rx = rx_new - network_traffic_info.rx;
    network_traffic_info.tx = tx_new;
    network_traffic_info.rx = rx_new;
    tx = tx / 500;
    rx = rx / 500;
    tx = math.floor(tx)
    rx = math.floor(rx)
    tx = tx / 10;
    rx = rx / 10; 
    return tx,rx
end

function getInfo()
    -- body
    --memony
    MemUsed = getMemUsage()

    --cpu
    CpuUsage = getCpuUsage()
    -- console.log(cpuUsage)
    
    --net type and ip address and Traffic
    local net_type
    local ip
    local net_tx
    local net_rx
    local network_info = os.networkInterfaces()
    -- console.log(network_info)
    if network_info.eth0 then
        net_type = '101';
        for k, v in ipairs(network_info.eth0) do
            if v.family == 'inet' then 
                ip = v.ip;
            end
        end
        net_tx, net_rx = getNetworkTraffic('eth0')
    elseif network_info.wlan0 then
        net_type = '50';
        -- net_type = getRSSI()
        for k, v in ipairs(network_info.wlan0) do
            if v.family == 'inet' then 
                ip = v.ip;
            end
        end
        net_tx, net_rx = getNetworkTraffic('wlan0')
    else
        net_type = 'unknown';
    end
    -- console.log(net_tx,net_rx)
    return MemUsed,CpuUsage,math.floor(os.uptime()),ip,net_type,net_tx,net_rx
end

function restart_network()
    console.log('restarting network')
    os.execute('ifdown wlan0')
    os.execute('ifup wlan0')
    console.log('restart network finish')
end

function read_config(file, key)
    local conf = config(file)
    local reader = conf:get(key)
    return reader
end

function write_config(file, key, value)
    local conf = config(file)
    -- console.log(params)
    conf:set(key, value)
    conf:commit()
end

function update_config(params)
    --beacon.conf
    -- console.log(params)
    configure = params or {}

    local conf = read_config('beacon' ,'reader') or {}
    conf.server = params.colserip
    write_config('beacon', 'reader', conf)
    -- console.log(read_config('beacon'))

    --monitor.conf
    local conf = read_config('monitor', 'config') or {}
    conf.update_url = params.update_url
    conf.update_time = params.update_time
    write_config('monitor', 'config', conf)
end

function update_program()
    --remove old file
    os.execute('rm -rf /usr/local/download/*')
    --download file
    console.log("download start")
    os.execute('wget -P /usr/local/download ' .. configure.update_url)

    local str = io.popen('ls /usr/local/download', "r")
    str = str:read("*a")
    if str == '' or str == nil then 
        console.log('download fail') 
        return -1 
    end
    console.log('download success')

    str = io.popen('dpkg -P node-lua-i386', "r")
    str = str:read("*a")
    console.log(str)
    console.log("dpkg -P finish")

    local filename = getFilename(configure.update_url)
    str = io.popen('dpkg -i /usr/local/download/' .. filename, "r")
    str = str:read("*a")
    console.log(str)
    console.log("dpkg -i finish")

    -- os.execute('dpkg -r node-lua-i386')
    -- os.execute('dpkg -i /usr/local/download/node-lua_i386.deb')
    console.log("ready to restart")
    os.execute('. /usr/local/lnode/bin/autorestart')

    -- local str = io.popen('wget -P /usr/local/download/ http://192.168.1.2/node/download/dist/linux/node-lua_i386.deb', "r")
    
    -- str = str:read("*a")
    -- console.log(str)
end

function monitor()
    -- body
    local mu, cu, uptime, ip, net_type, net_tx, net_rx = getInfo()
    -- console.log(net_tx,net_rx)
    local data = { mac = mac, target = target, ip = ip, version = version, mem_total = memtotal, mem_used = mu, cpu_usage = cu, uptime = uptime, net_type = net_type, net_tx = net_tx, net_rx = net_rx, config_timestamp = config_timestamp}
    if restart_beacon_program_state then
        data.restart = 1
        restart_beacon_program_state = false
    end
    -- console.log(config_timestamp)
    local options = {}
    options.data = json.stringify(data)
    options.contentType = 'application/json'
    -- console.log(options)
    request.post(URL .. '/monitor/push', options, function(err, response, body)
        if response then
            res_lost_count = 0
            -- console.log(response.statusCode, body)
            if body then
                body = json.parse(body)
                if(body.config) then
                    config_timestamp = body.config.config_timestamp;
                    update_config(body.config)
                end
                if body.message then
                    if body.message.name == 'reboot' then
                        os.execute('reboot')
                    elseif body.message.name == 'update' then
                        console.log("message update")
                        update_program()
                        -- if os.execute('wget -P /var/cache/apt/archives http://nms.beaconice.cn/node-lua_i386.deb') then
                        --     console.log('download success')
                        -- else
                        --     console.log('download fail')
                        -- end  
                    else

                    end
                end
            else

            end
        else 
            res_lost_count = res_lost_count + 1
            console.log('no response,res_lost_count = ' .. tostring(res_lost_count))
        end
        

        if res_lost_count >= 5 then
            res_lost_count = 0
            restart_network()
        end
    end)
end

function rpc_monitor()
    local RPC_PORT = 38888
    local method = 'alive'
    local params    = {}
    rpc.call(RPC_PORT, method, params, function(err, result)
        if (result) then
            -- console.log(result)
        else
            os.execute('lpm restart beacon')
            restart_beacon_program_state = true;
        end
    end)
end

local exports = {}

function exports.help()
    app.usage(utils.dirname())
end

function exports.start()
    print('start')
    local options = { form = { status = 'on' }}
    print('post')
    cpu_info.used_time = 0;
    cpu_info.total_time = 0;
    network_traffic_info.tx = 0;
    network_traffic_info.rx = 0;
    mac = getEth0Mac()
    -- target = getTarget()
    target = 'Intel'
    version = process.version
    memtotal = getMemTotal()
    setInterval(5000, monitor)
    setInterval(3600000, rpc_monitor)--beacon program monitor and restart
end

function exports.stop()
    os.execute('lpm kill monitor')
end

app(exports)
