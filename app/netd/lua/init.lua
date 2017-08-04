local app 		= require('app')
local utils     = require('utils')
local fs        = require('fs')
local child     = require('child_process')

local exec      = os.execute

local exports = {}

local color = console.color

function exports.start_dhcp_mode(settings)
    exports.stop_dhcp_mode()

    local rootPath = app.rootPath
    
    local interface = settings.interface or 'eth0'
    local script    = rootPath .. '/bin/udhcpc.lua'
    local pidfile   = '/tmp/udhcpc.pid'
    local hostname  = 'vision'

    local cmdline = 'udhcpc -i ' .. interface .. ' -p ' .. pidfile .. ' -H ' 
        .. hostname .. ' -s ' .. script
       
    print(cmdline)
    exec(cmdline)
end

function exports.start_static_mode(settings)
    local interface = settings.interface or 'eth0'
    exports.stop_dhcp_mode()
    
    exports.update_ip_settings   (interface, settings)
    exports.update_route_settings(interface, settings.gateway)
    exports.update_dns_settings  (interface, settings.dns)

    print("\nFinish!")
end

function exports.stop_dhcp_mode()
    exec("killall -q udhcpc")
    exec("usleep 100")
    exec("killall -q -9 udhcpc")
end

function exports.update_dns_settings(interface, dns, domain)
	print(color('string') .. 'Recreating DNS ... ', color())
	if (not dns) then
        return
    end
    
    local sb = StringBuffer:new()
    if (domain) then
        sb:append('search '):append(domain):append('\n')
    end

    local tokens = dns:split(' ')
    for _, value in pairs(tokens) do 
        sb:append('nameserver '):append(value):append('\n')
        print(' Adding resolv: ' .. value)
    end
    local newData = sb:toString()

    local filename = '/etc/resolv.conf'
    local fileData = fs.readFileSync(filename)

    if (newData ~= fileData) then
        fs.writeFileSync(filename .. "-$$", newData)
        os.rename(filename .. "-$$", filename)
    end
end

function exports.update_ip_settings(interface, settings)
    local ip = settings.ip
    print(" Settings IP address " .. ip .. ' on ' .. interface)

	local netmask = ""
	if (settings.netmask) then
		netmask = 'netmask ' .. settings.netmask 
	end

	local broadcast = 'broadcast +'
	if (settings.broadcast) then
		broadcast = 'broadcast ' .. settings.broadcast
	end
    
	exec('ifconfig ' .. interface .. ' ' .. ip .. ' ' .. netmask .. ' ' .. broadcast)
    exec('ifconfig lo up')
    exec('route add -net 239.0.0.0 netmask 255.0.0.0 ' .. interface)
end

function exports.update_route_settings(interface, router)
    print(color('string') .. 'Applying router settings...', color())
    if (not router) then
        return
    end
    
    local cmdline = 'route del default gw 0.0.0.0 dev ' .. interface
    while (true) do 
        local ret = exec(cmdline)
        if (not ret) then
            break
        end
    end

    local tokens = router:split(' ')
    for i = 1, #tokens do
        local gw = tokens[i]
        local metric = i - 1
        print(' Adding router: ' .. tostring(gw))
        exec("route add default gw " .. gw .. ' dev ' .. interface 
            .. ' metric ' .. metric)
    end
end

return exports
