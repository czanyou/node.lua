local fs      = require("fs")
local conf    = require('ext/conf')
local json    = require('json')
local lpm     = require('ext/lpm')
local path    = require('path')
local utils   = require('utils')
local thread  = require('thread')
local qstring = require('querystring')
local net     = require('net')
local uv      = require('uv')
local httpd   = require('httpd')

local spawn   = require('child_process').spawn
local exec    = require('child_process').exec

-- methods
local methods  = {}
local hostname = 'inode'
local session  = {}

local JSON_RPC_VERSION  = "2.0"
local SHELL_RUN_TIMEOUT = 2000

session.token  = 'test'

local isWindows = (os.platform() == 'win32')

local function getEnvironment()
    return { hostname = hostname, path = process.cwd() }
end

function methods.completion(response, id, token, env, pattern, command)
    local result = {}
    local completion = {}

    local scanPath = path.dirname(pattern)
    local filename = path.basename(pattern)

    local basePath = scanPath or ''

    if (scanPath == '.') then 
        scanPath = process.cwd() 
        basePath = ''
    end

    if (#basePath > 0) and (not basePath:endsWith('/')) then
        basePath = basePath .. '/'
    end

    if (pattern:endsWith('/')) then
        scanPath = pattern
        filename = ''
        basePath = scanPath
    end

    --console.log('scan', scanPath, basePath, filename)

    local files = fs.readdirSync(scanPath)
    --console.log(files)

    local index = 0
    for _, file in ipairs(files) do
        if (file:startsWith(filename)) then
            completion[#completion + 1] = basePath .. file
        end

        index = index + 1
        if (index > 100) then
            break
        end
    end

    --console.log(completion)
    --console.log(pattern, command)

    result.completion = completion

    local ret = { jsonrpc = JSON_RPC_VERSION, id = id, result = result }
    response:json(ret)
end

function methods.login(response, id, username, password)
	local result = {}

    --print(username, password)

    if (username ~= 'admin' and username ~= 'root') then
        result.falsy = "Invalid username."

    elseif (password ~= 'admin' and password ~= 'root' and password ~= '888888') then
        result.falsy = "Invalid password."

    else
	   result.token = session.token
	   result.environment = getEnvironment()
    end

	local ret = { jsonrpc = JSON_RPC_VERSION, id = id, result = result }
	response:json(ret)
end

function methods.run(response, id, token, env, cmd, ...)
	local result = {}

    if (not isWindows) then
        -- 重定向 stderr(2) 输出到 stdout(1)
        cmd = cmd .. " 2>&1"
    end

    -- [[
    local options = { timeout = SHELL_RUN_TIMEOUT, env = process.env }

    exec(cmd, options, function(err, stdout, stderr) 
        --console.log(err, stdout, stderr)
        if (not stdout) or (stdout == '') then
            stdout = stderr
        end

        if (err and err.message) then
            stdout = err.message .. ': \n\n' .. stdout
        end

        os.execute(cmd)

        result.output = stdout
        result.environment = getEnvironment()

        local ret = { jsonrpc = JSON_RPC_VERSION, id = id, result = result }
        response:json(ret)
    end)
    --]]
end

function methods.cd(response, id, token, env, dir)
    local result = {}

    if (type(dir) == 'string') and (#dir > 0) then
        local cwd = process.cwd()
        local newPath = dir
        if (not dir:startsWith('/')) then
            newPath = path.join(cwd, dir)
        end
        --console.log(dir, newPath)

        if newPath and (newPath ~= cwd) then
            local ret, err = process.chdir(newPath)
            --console.log(dir, newPath, ret, err)
            if (not ret) then
                result.output = err or 'Unable to change directory'
            end
        end
    end

    result.environment = getEnvironment()

    local ret = { jsonrpc = JSON_RPC_VERSION, id = id, result = result }
    response:json(ret)
end

-- call API methods
local function do_rpc(request, response)
    local rpc = request.body
    if (type(rpc) ~= 'table') then
    	response:sendStatus(400, "Invalid JSON-RPC request format")
    	return
    end

    local method = methods[rpc.method]
    if (not method) then
    	response:sendStatus(400, "Method not found: " .. tostring(rpc.method))
    	return
    end

    if (not httpd.isLogin(request)) then
        response:sendStatus(401, "User not login")
        return
    end

    method(response, rpc.id, table.unpack(rpc.params))
end

request.params = qstring.parse(request.uri.query) or {}
request:readBody(function()
    do_rpc(request, response)
end)

return true
