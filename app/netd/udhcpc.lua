#!/usr/bin/env lnode

local utils = require('utils')
local env   = require('env')
local fs    = require('fs')
local json  = require('json')
local netd  = require('netd')

local exec   = os.execute

local action = arg[1]

local interface = env.get('interface') or 'eth0'

if (action == 'deconfig') then
	print('Settings IP address 0.0.0.0 on ' .. interface)
	exec('ifconfig ' .. interface .. ' 0.0.0.0')

elseif (action == 'bound') or (action == 'renew') then
	local settings = {}
	settings.action	 	 = action
	settings.interface	 = interface
	settings.ip 		 = env.get('ip') or '0.0.0.0'
	settings.subnet 	 = env.get('subnet')
	settings.router 	 = env.get('router')
	settings.broadcast 	 = env.get('broadcast')
	settings.dns 		 = env.get('dns')
	settings.lease 	 	 = env.get('lease') or '0'
	settings.domain 	 = env.get('domain')


	netd.update_ip_settings   (interface, settings)
	netd.update_route_settings(interface, settings.router)
	netd.update_dns_settings  (interface, settings.dns, settings.domain)


	fs.writeFile('/tmp/dhcp.json', json.stringify(settings))

else
	print('Error: should be called from udhcpc.')

end
