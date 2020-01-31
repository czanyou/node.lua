local fs   = require('fs')
local conf = require('app/conf')

local function onConfigReset()
	local nodePath = conf.rootPath
	console.log('nodePath', nodePath)

	local defaultConfig = fs.readFileSync(nodePath .. '/conf/default.conf')
	local userConfig = fs.readFileSync(nodePath .. '/conf/user.conf')
	local networkConfig = fs.readFileSync(nodePath .. '/conf/network.conf')
	local networkDefaultConfig = fs.readFileSync(nodePath .. '/conf/network.default.conf')

	if (not defaultConfig) or (defaultConfig == '') then
		print("Error: `default.conf` is empty")

	elseif (defaultConfig == userConfig) then
		print("Error: the same file")

	else
		print("Config reset...")
		fs.writeFileSync(nodePath .. '/conf/user.conf', defaultConfig)
	end

	if (networkConfig and (networkConfig ~= networkDefaultConfig)) then
		-- fs.writeFileSync(nodePath .. '/conf/network.conf', networkDefaultConfig)
	end
end

onConfigReset()
