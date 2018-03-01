local app       = require('app')
local utils     = require('util')
local request   = require('http/request')
local fs        = require('fs')
local device    = require('sdl')
local json      = require('json')
local config    = require('app/conf')
local rpc       = require('app/rpc')
local miniz     = require('miniz')
local URL       = 'http://nms.beaconice.cn:3000'
-- local URL       = 'http://192.168.2.15:3000'
-------------------------------------------------------------------------------
-- exports

local cpu_info = {}
local configure = {}
local network_traffic_info = {}
local config_timestamp = 1
local res_lost_count = 0
local mac = ""
local target = ""
local version = ""
local memtotal = ""
local restart_beacon_program_state = false

local function getNodePath()
	return config.rootPath
end

local function getRootPath()
	return '/'
end

function fileExists(path)
  local file = io.open(path, "rb")
  if file then file:close() end
  return file ~= nil
end

--获取文件名
function getFileName(str)
    local idx = str:match(".+()%.%w+$")
    if(idx) then
        return str:sub(1, idx-1)
    else
        return str
    end
end

--获取扩展名
function getExtension(str)
    return str:match(".+%.(%w+)$")
end

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

function updateFile(rootPath, reader, index)
	local join 	 	= path.join

	--thread.sleep(10) -- test only

	if (not rootPath) or (not rootPath) then
		return -6, 'invalid parameters' 
	end

	local filename = reader:get_filename(index)
	if (not filename) then
		return -5, 'invalid source file name: ' .. index 
	end	

	-- read source file data
	local fileData 	= reader:extract(index)
	if (not fileData) then
		return -3, 'invalid source file data: ', filename 
	end

	-- write to a temporary file and check it
	local tempname = join(rootPath, filename .. ".tmp")
	local dirname = path.dirname(tempname)
	fs.mkdirpSync(dirname)

	local ret, err = fs.writeFileSync(tempname, fileData)
	if (not ret) then
		return -4, err, filename 
	end

	local destInfo = fs.statSync(tempname)
	if (destInfo == nil) then
		return -1, 'not found: ', filename 

	elseif (destInfo.size ~= #fileData) then
		return -2, 'invalid file size: ', filename 
	end

	-- rename to dest file
	local destname = join(rootPath, filename)
	os.remove(destname)
	local destInfo = fs.statSync(destname)
	if (destInfo ~= nil) then
		return -1, 'failed to remove old file: ' .. filename 
	end

	os.rename(tempname, destname)
	return 0, nil, filename
end

function updateAllFiles(reader, callback)
	callback = callback or noop

	local rootPath = getRootPath()
	local files = self.list or {}
	print('Upgrading system "' .. rootPath .. '" (total ' 
		.. #files .. ' files need to update).')

	--console.log(self)

	local count = 1
	for _, index in ipairs(files) do

		local ret, err, filename = updateFile(rootPath, reader, index)
		if (ret ~= 0) then
			--print('ERROR.' .. index, err)
            self.faileds = (self.faileds or 0) + 1
		end
        console.log('update', count, filename, ret, err)
		-- self:emit('update', count, filename, ret, err)
		count = count + 1
	end

	-- self:emit('update')

	fs.chmodSync(rootPath .. '/usr/local/lnode/bin/lnode', 511)
	fs.chmodSync(rootPath .. '/usr/local/lnode/bin/lpm', 511)

	callback(nil, self)
end

function update_patch()
    --remove old file
    os.execute('rm -rf /usr/local/download/*')
    --download file
    console.log("download start")
    console.log(process.version)
    request.get(URL .. '/patch/?model=Intel&version=' .. process.version, function(err, response, body)
        if(response) then
            if response.statusCode == 200 then
                fs.writeFile('/usr/local/download/patch.zip', body, function (err) 
                    if (err) then return nil, err end
                    print('file is save') --文件被保存
                    print('update patch now')
                    os.execute('. /usr/local/lnode/app/gateway/sh/autoupdatepatch')
                end)
            end
        end
    end)
end

function upgrade_firmware()
    -- check folder
    if not fileExists('/usr/local/download') then os.execute('mkdir /usr/local/download') end
    --remove old file
    os.execute('rm -rf /usr/local/download/*')
    --download file
    -- console.log("download start")
    -- os.execute('wget -P /usr/local/download ' .. URL .. '/firmware/?model=Intel&version=' .. process.version)
    -- console.log('wget -P /usr/local/download ' .. URL .. '/firmware/?model=Intel&version=' .. process.version)

    -- local str = io.popen('ls /usr/local/download', "r")
    -- str = str:read("*a")
    -- if str == '' or str == nil then 
    --     console.log('download fail') 
    --     return -1 
    -- end
    -- console.log('download success')

    request.get(URL .. '/firmware/?model=Intel&version=' .. process.version, function(err, response, body)
        if response and response.statusCode == 200 then 
            -- get file name
            local filename_str = response.headers[3][2]
            console.log(filename_str)
            local filename_obj = {}
            for k, v in string.gmatch(filename_str, '(%w+)="(%g+)"') do
                filename_obj[k] = v
            end
            local filename = filename_obj.filename
            local extension_name = getExtension(filename)--获取拓展名，判断文件类型
            fs.writeFile('/usr/local/download/firmware.' .. extension_name, body, function (err) 
                if (err) then return nil, err end
                print('file is save') --文件被保存
                if extension_name == 'deb' then
                    print('upgrade firmware now')
                    os.execute('. /usr/local/lnode/app/gateway/sh/autoupdatefirmware')
                elseif extension_name == 'zip' then
                    print('update patch now')
                    os.execute('. /usr/local/lnode/app/gateway/sh/autoupdatepatch')
                else
                    console.log('unknown type file ')
                end
                -- print('upgrade firmware now')
                -- os.execute('. /usr/local/lnode/app/gateway/sh/autoupdatefirmware')
            end)
        end
    end)
    -- -- uninstall old deb package
    -- str = io.popen('dpkg -P node-lua-i386', "r")
    -- str = str:read("*a")
    -- console.log(str)
    -- console.log("dpkg -P finish")
    -- -- install new deb package
    -- local filename = getFilename(configure.update_url)
    -- str = io.popen('dpkg -i /usr/local/download/' .. filename, "r")
    -- str = str:read("*a")
    -- console.log(str)
    -- console.log("dpkg -i finish")
    -- -- restart all app
    -- console.log("ready to restart")
    -- os.execute('. /usr/local/lnode/bin/autorestart')
end

function monitor_post()
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
                    elseif body.message.name == 'upgrade' then
                        console.log("message upgrade")
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

function exports.monitor_init()
    print('start')
    -- local options = { form = { status = 'on' }}
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
end

function exports.monitor_post()
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
        
    end)
end

function exports.heartbeat_post()
    local data = { if_modified_since = config_timestamp }
    local options = {}
    options.data = json.stringify(data)
    options.contentType = 'application/json'
    request.post(URL .. '/heartbeat', options, function(err, response, body)
        if response then
            res_lost_count = 0
            -- console.log(response.statusCode, body)
            if body then
                body = json.parse(body)
                if(body.config) then
                    config_timestamp = body.config.last_modified;
                    update_config(body.config)
                end
                if body.actions then
                    if body.actions.name == 'reboot' then
                        os.execute('reboot')
                    elseif body.actions.name == 'restart' then
                        console.log("action restart")
                        os.execute('. /usr/local/lnode/app/gateway/sh/autorestart')
                    elseif body.actions.name == 'update' then
                        console.log("action update")
                        upgrade_firmware()
                    -- elseif body.actions.name == 'patch' then
                    --     console.log("action patch")
                    --     update_patch()
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

function exports.patch_update()

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
    -- setInterval(5000, monitor)
    -- setInterval(3600000, rpc_monitor)--beacon program monitor and restart
end

function exports.stop()
    os.execute('lpm kill monitor')
end

return exports

-- app(exports)
