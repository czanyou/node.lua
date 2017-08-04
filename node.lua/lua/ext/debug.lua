--[[

Copyright 2016 The Node.lua Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

local fs        = require('fs')
local json      = require('json')
local path      = require('path')
local utils     = require('utils')
local qstring   = require('querystring')

local request  	= require('http/request')
local conf   	= require('ext/conf')
local ext   	= require('ext/utils')

local exports = {}

local formatFloat 		= ext.formatFloat
local formatBytes 		= ext.formatBytes
local noop 		  		= ext.noop

local SSDP_WEB_PORT 	= 9100


function exports.connect(hostname, password)
	-- TODO: connect
	if (not hostname) or (not password) then
		print('\nUsage: ldb connect <hostname> <password>')

	end

	local grid = ext.table({20, 40})

	local deploy = conf('deploy')
	if (deploy) then
		if (hostname) then
			deploy:set('hostname', hostname)
		end

		if (password) then
			deploy:set('password', password)
		end

		deploy:commit()

		hostname = deploy:get('hostname')
	end

	if (not hostname) then
		return
	end
		
	print("Reading device information: `" .. hostname .. '`...')
	local url = "http://" .. hostname .. ":" .. SSDP_WEB_PORT .. "/device"
    request(url, function(err, response, data)
        --console.log(err, data)

        if (err) then
            print(err)
            return
        end

        local data = json.parse(data) or {}
        local device = data.device or {}
        --console.log('device info:', device)

		print('')
		print(' = Device information:')
		print('')

		grid.cell('key', 'value')
        grid.line('=')
        for key, value in pairs(device) do
        	if (type(value) == 'table') then
        		value = '{}'
        	end
        	grid.cell(key, value)
        end

        grid.line()

        print('')
        print(' = Finish.')
        print('')
    end)

end

function exports.sh(cmd, ...)
	if (not cmd) then
		print("Error: the '<cmd>' argument was not provided.")
		print("Usage: ldb sh <cmd> [args...]")
		return
	end

	local deploy = conf('deploy')
	local hostname = deploy:get('hostname')
	if (not hostname) then
		print("Error: the '<hostname>' argument was not provided.")
		print("Please use 'ldb connect' to provide a hostname.")
		return
	end

	local url = "http://" .. hostname .. ":" .. SSDP_WEB_PORT .. "/shell"
	local params = table.pack(...)
	if (#params > 0) then
		cmd = cmd .. ' ' .. table.concat(params, ' ')
	end

	url = url .. '?cmd=' .. qstring.escape(cmd)

	--console.log(url)
    request(url, function(err, response, data)
        if (err) then
            print(err)
            return
        end

        local result = json.parse(data) or {}
        if (result.output) then
        	print(result.output)
        	return
        else 
        	print('device returned: ', result.error or result.ret)
        end
    end)
end

function exports.deploy(hostname, password)
	print("\nUsage: ldb deploy <hostname> <password>\n")

	if (not hostname) then
		local deploy = conf('deploy')
		hostname = deploy:get('hostname')
		password = password or deploy:get('password')

		if (not hostname) then
			print("Need hostname!")
			return
		end
	end

	local timerId

	local onDeployResponse = function(err, percent, response, body)
		clearInterval(timerId)

		if (err) then print(err) return end

		if (not response) then
			console.write('\rUploading (' .. percent .. '%)...')
			return
		end
		
		local result = json.parse(body) or {}
		if (result.ret ~= 0) then
			print('\nDeploy error: ' .. tostring(result.error))
			return
		end

		print('\nDeploy result:\n')

		local grid = ext.table({20, 40})
		grid.line()
		grid.cell('Key', 'Value')
		grid.line('=')
		for key, value in pairs(result.data) do 
			grid.cell(key, value)
		end
		grid.line()

		print('\nFinish.')
	end

	local onGetDeviceInfo = function(err, response, body)
		if (err) then print('\nConnect to server failed: ', err) return end

		local systemInfo = json.parse(body) or {}
		local device = systemInfo.device
		if (not device) then
			print('\nInvalid device info')
			return
		end

		local target  = device.target
		local version = device.version
		if (not target) then
			print('\nInvalid device target type')
			return
		end

		print('\rChecking "' .. hostname .. '"... [done]')
		print('Current device version: ' .. target .. '@' .. tostring(version))

		local filename = path.join(process.cwd(), 'build', 'nodelua-' .. target .. '-sdk.zip');
		console.write('Reading "' .. filename .. '"...')

		if (not fs.existsSync(filename)) then
			print('\nDeploy failed: Update file not found, please build it firist!')
			return
		end

		local filedata = fs.readFileSync(filename)
		if (not filedata) then
			print('\nDeploy failed: Invalid update file!')
			return
		end

		print('\rReading "' .. filename .. '"...  [' .. #filedata .. ' Bytes]')

		timerId = setInterval(500, function()
			console.write('.')
		end)

		local url = 'http://' .. hostname .. ':' .. SSDP_WEB_PORT .. '/upgrade'
		print('Uploading to "' .. url .. '"...')

		local options = { data = filedata }
		request.upload(url, options, onDeployResponse)
	end

	-- 
	console.write('Checking "' .. hostname .. '"...')
	local url = 'http://' .. hostname .. ':' .. SSDP_WEB_PORT .. '/device'
	request(url, onGetDeviceInfo)
end

function exports.disconnect()
	local deploy = conf('deploy')
	if (deploy) then
		deploy:set('hostname', nil)
		deploy:set('password', nil)
		deploy:commit()

		print("Disconnected!")
	end
end

function exports.info()
	local deploy = conf('deploy')
	if (not deploy) then
		return
	end

	local grid = ext.table({20, 40})

	print('')
	print(' = Current settings:')
	print('')

	grid.cell('key', 'value')
	grid.line('-')
	grid.cell('hostname', (deploy:get('hostname') or '-'))
	grid.cell('password', (deploy:get('password') or '-'))
	grid.line()
	print('')
end

function exports.install(filename)
	
end

function exports.installApplication(name)
	local dest = nil
	if (name == '-g') then
		dest = 'global'
		name = nil
	end

	if (not name) then
		print([[
Usage: ldb install [options] <name>

options:
  -g install to global
]])
	end

	-- application name
	local package = require('ext/package')

	if (name) then
		package.pack(name)

	else
		local info  = app.info(name)
		if (info) then
			name = info.name
			package.pack()
		end

		if (not name) or (name == '') then
			local filename = path.join(process.cwd(), 'packages.json') or ''
			print("Install: no such file, open '" .. filename .. "'")
			return
		end
	end

	-- update file
	local tmpdir = path.dirname(os.tmpname())
	local buildPath = path.join(tmpdir, 'packages')
	local filename = path.join(buildPath, "" .. name .. ".zip")
	print("Install: open '" .. filename .. "'")

	if (not fs.existsSync(filename)) then
		print('Install: no such application update file, please build it first!')
		return
	end

	-- hostname
	local deploy = conf('deploy')
	local hostname = deploy:get('hostname')
	password = password or deploy:get('password')

	-- update file content
	local filedata = fs.readFileSync(filename)
	if (not filedata) then
		print('Install failed:  Invalid update file content!')
		return
	end

	-- post file
	print('Install [' .. name .. '] to [' .. hostname .. ']')

	local options = {data = filedata}

	local url = 'http://' .. hostname .. ':' .. SSDP_WEB_PORT .. '/install'
	if (dest) then
		url = url .. "?dest=" .. dest
	end

	print('Install url:    ' .. url)
	local request = require('http/request')
	request.post(url, options, function(err, response, body)
		if (err) then print(err) return end

		local result = json.parse(body) or {}
		if (result.ret == 0) then
			console.log(result.data)
			print('Install finish!')
		else
			print('Install error: ' .. tostring(result.error))
		end
	end)
end

function exports.remove(name)
	if (not name) or (name == '') then
		print([[
Usage: ldb remove [options] <name>

options:
  -g remove from global path
]])		
		return
	end

end

return exports

