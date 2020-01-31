local path 	 	= require('path')
local process 	= require('process')
local express 	= require('express')

local interval 	= 100

local function http_loop()
	local cwd = process.cwd()

	local root = path.join(cwd, "../lua/www")
	--print('root', root)

	local app = express({root=root})
	app:listen(8090)

	--local server = express.Server:new()
	--server.root = root;
	--server:start(8098)
	--runLoop()
end

local function main()
	print('starting...')
	
	local isRunning = true
	if (isRunning) then
		local ret, err = pcall(http_loop)
		if (not ret or err) then
			print('main', ret, err)
		end

		--interval = math.min(1000 * 6, interval * 2)
		--thread.sleep(interval)

		isRunning = true -- debug only
	end

	runLoop()
end

main()
