local config = require('app/conf')
local request = require('http/request')
local json = require('json')
local qs = require('querystring')
local app = require('app')

local exports = {}

local function getDevieInfo(callback)
    local baseurl = exports.baseurl
    local url = baseurl .. '/device/info'
    request.get(url, function(err, response, body)
        local result = body and json.parse(body)

        local value = response and response.headers['Set-Cookie']
        local data = value and qs.parse(value, ';')
        if (data and data.LSESSIONID) then
            exports.sessionId = data.LSESSIONID
        end

        callback(err, result)
    end)
end

local function authLogin(callback)
    local baseurl = exports.baseurl
    local username = exports.username or 'admin'
    local password = exports.password or 'wot2019'

    local url = baseurl .. '/auth/login'
    local data = { username = username, password = password }
    local headers = { Cookie = "LSESSIONID=" .. (exports.sessionId or '') }
    local options = { json = data, headers = headers }
    request.post(url, options, function(err, response, body)
        local result = body and json.parse(body)
        callback(err, result)
    end)
end

local function checkLogin(callback)

    getDevieInfo(function(err, result)
        local code = result and result.code
        -- console.log(err, result)
        local deviceInfo = result or {}

        if (code ~= 401) then
            err = err or (result and result.error)
            if (code and err) then
                return print('getDevieInfo: ', err, code)
            end
        end

        if (deviceInfo.version) then
            print('= Device Information:')
            print('Model number: ' .. tostring(deviceInfo.modelNumber))
            print('Serial number: ' .. tostring(deviceInfo.serialNumber))
            print('Software version: ' .. tostring(deviceInfo.softwareVersion))
            print('')
        end

        authLogin(function(err, result)
            if (err) then
                return print('Login failed: ', err)
            end

            code = result and result.code
            if (code ~= 0) then
                return print('Login failed: ', code, result and result.error)
            end

            print('Login: successful')
            callback()
        end)
    end)
end

function exports.restart(name)
    print("restart application on remote device")
    print("")
    print("Usage: lci restart <name>")
    print("")

    local address  = app.get('lbuild.address')
    local username = app.get('lbuild.username')
    local password = app.get('lbuild.password')

    local baseurl = 'http://' .. (address or '127.0.0.1')

    if (not name) then
        return print("missing 'name' parameter")
    end

    exports.baseurl = baseurl
    exports.username = username or 'admin'
    exports.password = password or 'wot2019'

    print('Address: ' .. baseurl)
    print('')

    local function sendRestart(name, callback)
        local url = baseurl .. '/system/action'
        local data = { restart = name }
        local headers = { Cookie = "LSESSIONID=" .. (exports.sessionId or '') }
        local options = { json = data, headers = headers }
        request.post(url, options, function(err, response, body)
            local result = body and json.parse(body)
            callback(err, result)
        end)
    end

    checkLogin(function(err, result)
        sendRestart(name, function(err, result)
            if (err) or (not result) then
                return print('Restart failed: ', err)
            end

            if (result.code and result.error) then
                return print('Restart failed: ', result)
            end

            print('Restart: ' .. tostring(result.message))
        end)
    end)
end

function exports.update()
    print("Upload and install firmware for remote device")
    print("")
    print("Usage: lci update")
    print("")

    local address  = app.get('lbuild.address')
    local filename = app.get('lbuild.filename')
    local username = app.get('lbuild.username')
    local password = app.get('lbuild.password')
    local version  = app.get('lbuild.version')
    local board    = app.get('lbuild.board')
    local arch     = app.get('lbuild.arch')

    if (not address) then
        return print("missing 'address' parameter")
    end

    if (not filename) or (filename == '@') then
        board = board or 'dt02b'
        arch = arch or 'arm'
        filename = 'build/sdk/' .. board .. '-' .. arch .. '-linux-' .. (version or process.version) .. '.bin'
    end

    local baseurl = 'http://' .. (address or '127.0.0.1')
    exports.baseurl = baseurl
    exports.username = username or 'admin'
    exports.password = password or 'wot2019'

    print('Address: ' .. baseurl)
    print('Filename: ' .. filename)
    print('')

    local startTime = Date.now()

    local function fileUpload(callback)
        local url = baseurl .. '/upload'
        local headers = { Cookie = "LSESSIONID=" .. (exports.sessionId or '') }
        local options = { headers = headers }

        local profile = config('user')
        options.filename = filename or profile:get('upload') or 'update.bin'
        print('filename: ' .. options.filename)

        request.upload(url, options, function(err, percent, response, body)
            local result = body and json.parse(body)
            callback(err, result)
        end)
    end

    local function fileInstall(callback)
        local url = baseurl .. '/system/action'
        local data = { install = 3 }
        local headers = { Cookie = "LSESSIONID=" .. (exports.sessionId or '') }
        local options = { json = data, headers = headers }
        request.post(url, options, function(err, response, body)
            local result = body and json.parse(body)
            callback(err, result)
        end)
    end

    local function startInstall()
        fileUpload(function(err, result)
            err = err or (result and result.error)
            if (err) then
                return print('upload failed: ', err)
            end

            local code = result and result.code
            print('Firmware uploaded: path=' .. tostring(result.path) .. ' size=' .. tostring(result.size))
            print('')

            fileInstall(function(err, result)
                err = err or (result and result.error)
                if (err) then
                    return print('install failed: ', json.stringify(err))
                end

                code = result and result.code
                print(result.output)

                local endTime = Date.now()
                print("Install completed: " .. (endTime - startTime) .. 'ms')
            end)
        end)
    end

    checkLogin(function(err, result)
        startInstall()
    end)
end

function exports.config()
	print('address:  ', app.get('lbuild.address'))
	print('name:     ', app.get('lbuild.name'))
	print('filename: ', app.get('lbuild.filename'))
    print('board:    ', app.get('lbuild.board'))
    print('arch:     ', app.get('lbuild.arch'))
	print('version:  ', app.get('lbuild.version'))
	print('username: ', app.get('lbuild.username'))
	print('password: ', app.get('lbuild.password'))
end

function exports.get(name)
	local value = app.get('lbuild.' .. name)
	console.log(name, '=', value)
end

function exports.set(name, value)
	app.set('lbuild.' .. name, value)
end


return exports
