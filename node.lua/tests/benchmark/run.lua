local tap 	= require("ext/tap")
local uv  	= require("uv")
local utils = require('util')

tap.testAll(utils.dirname())

local fs = require('fs')

local lasttotal, lastused

function stat()
	local filedata = fs.readFileSync('/proc/stat')
	--console.log(filedata)

	local fmt = '([%w]+)[ ]+([%d]+)[ ]+([%d]+)[ ]+([%d]+)[ ]+([%d]+)[ ]+([%d]+)'
	local n, p, name, user, nice, system, idle, iowait = filedata:find(fmt)

	--console.log(n, p, name, user, nice, system, idle, iowait)

	local current_total = user + nice + system + idle + iowait
	--console.log(total)

	local current_used = user + nice + system + iowait
	--console.log(used)

	--console.log(math.floor(used * 100 / total) .. '%')

	if (lasttotal) then
		local total = current_total - lasttotal
		local used  = current_used  - lastused

		console.write('cpu: ' .. math.floor(used * 100 / total) .. '%    \r')
	end

	lasttotal = current_total
	lastused = current_used
end

function stat2()
	local filedata = fs.readFileSync('/proc/net/dev')
	console.log(filedata)


end

stat2()
--setInterval(500, stat2)
