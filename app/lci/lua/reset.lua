local fs		= require('fs')
local conf		= require('app/conf')

local function onConfigReset()
	local nodePath = conf.rootPath
	local defaultConfig = fs.readFileSync(nodePath .. '/conf/default.conf')
	local userConfig = fs.readFileSync(nodePath .. '/conf/user.conf')

	if (not defaultConfig) or (defaultConfig == '') then
		print("Error: `default.conf` is empty")

	elseif (defaultConfig == userConfig) then
		print("Error: the same file")

	else
		print("Config reset...")
		fs.writeFileSync(nodePath .. '/conf/user.conf', defaultConfig)
	end
end

onConfigReset()
