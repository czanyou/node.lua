local path 	 = require('path')
local utils  = require('utils')
local core 	 = require('core')
local fs 	 = require('fs')

local exports = {}

-------------------------------------------------------------------------------
-- route


function exports.getIPAddress(facename)

end

function exports.getMacAddress(facename)

end

function exports.hasInterface(facename)


end

function exports.isLinkedIn(facename)
	local filename = "/sys/class/net/" .. facename .. "/carrier"
	local fileData = fs.readFileSync(filename)



end

function exports.setAddress(facename, ip, netmask)
	exec("ifconfig " .. facename .. " " .. ip .. " netmask " .. netmask .." up")
end

function exports.netdown(facename)
	if (facename) then
		exec("ifconfig " .. facename .. " down")
	end
end

-------------------------------------------------------------------------------
-- route

local route = {}
exports.route = route

function route.addDefaultGateway(gateway, facename)
	local cmdline = string.format("route add default gw %s %s", gateway, facename)

	exec(cmdline)
end

function route.hasRoute(dest, gateway, facename)

end

function route.removeDefaultGateway(facename)
	if (facename) then
		while (route.hasRoute("0.0.0.0", nil, facename)) do
			exec("route del default " .. facename);
		end

	else
		while (route.hasRoute("0.0.0.0", nil, nil)) do
			exec("route del default");
		end
	end
end

function route.isRoute(facename)

end

function route.addNetwork(network, netmask, facename)
	local cmdline = string.format("route add -net %s netmask %s %s", network, netmask, facename)
	exec(cmdline)
end

return exports
