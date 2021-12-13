local app = require('app')
local fs = require('fs')
local util = require('util')
local json = require('json')

local exports = {}

function exports.button()
    local devices = require('devices')

    local timer = nil
    local state, err = devices.getButtonState('reset')
    if (err) then
        return print('Read reset button state error: ', err)
    end

    print('Current RESET button state is: ' .. state)

    if (state ~= 1) then
        return print('Invalid reset button state', state)
    end

    print('Wait button to be pressed...')

    timer = setInterval(100, function()
        state, err = devices.getButtonState('reset')
        if (state == 0) then
            print('RESET button: ' .. console.dump(state or err))
            clearInterval(timer)
        end
    end)
end

function exports.check()
    local errors = {}
    local failures = 0
    local total = 0

    local function assert(value, message)
        total = total + 1
        if (not value) then
            failures = failures + 1
            table.insert(errors, message)
        end
    end

    local function checkConfig(name)
        local value = app.get(name)
        if (value) then
            total = total + 1
            print(name .. ': ' .. value)
        else
            failures = failures + 1
            table.insert(errors, '系统设置参数 ' .. name .. ' 为空')
        end
    end

    local function checkFile(basePath, name)
        local filename = basePath .. name

        print("");
        print('Check: ' .. filename .. '\n------')
        if (fs.existsSync(filename)) then
            total = total + 1
            local data = fs.readFileSync(filename)
            print(data and #data)

        else
            failures = failures + 1
            table.insert(errors, '`' .. name .. '` 文件不存在')
        end
    end

    print("Check config: \n======")
    checkConfig('did')
    checkConfig('base')
    checkConfig('mqtt')
    checkConfig('secret')
    print("");

    print("Check files: \n======")
    checkFile('/usr/local/lnode/conf/', 'default.conf');
    checkFile('/etc/init.d/', 'S88lnode');
    checkFile('/usr/share/udhcpc/', 'default.script');
    print("");

    print('total: ' .. total)
    print('failds: ' .. failures)

    console.printr(errors)
end

function exports.cloud()
    local request = require('http/request')

    local did = app.get('did')
    local base = app.get('base')
    local url = base .. '/device/firmware?did=' .. did

    console.log(url)
    request.get(url, function(err, res, body)
        if (err) then
            return console.log(err)
        end

        console.log(res.statusCode, res.statusMessage, json.parse(body))
    end)
end

function exports.install()
    local exec  = require('child_process').exec

    local function shellExecute(cmdline, message)
        console.log('cmdline: ', cmdline)
        exec(cmdline, {}, function(err, stdout, stderr)
            console.log('exec', err, stdout, stderr)
        end)
    end

    shellExecute("lpm install /tmp/upload")
end

function exports.led()
    local devices = require('devices')

    local function setLedOn()
        print("LED is on")
        devices.setLEDStatus('green', 'on')
        devices.setLEDStatus('blue', 'on')
        devices.setLEDStatus('yellow', 'on')
    end

    local function setLedOff()
        print("LED is off")
        devices.setLEDStatus('green', 'off')
        devices.setLEDStatus('blue', 'off')
        devices.setLEDStatus('yellow', 'off')
    end

    setLedOn()
    setTimeout(2000, function()
        setLedOff()

        setTimeout(2000, function()
            setLedOn()

            setTimeout(2000, function()
                setLedOff()
            end)
        end)
    end)
end

function exports.switch()
    local devices = require('devices')

    local _, err = devices.setSwitchState('bluetooth', "1", function ()
        local state, err = devices.getSwitchState()
        if (state ~= 1) then
            console.log('BLE switch state is not 1: ', state or err)
        end
    end)

    if (err) then
        console.log('Set BLE switch state to 1: ', err)
    end

    setTimeout(1000, function()
        local _, err = devices.setSwitchState('bluetooth', "0", function()
            local state, err = devices.getSwitchState()
            if (state ~= 0) then
                console.log('BLE switch state is not 0: ', state or err)
            else
                console.log('done')
            end
        end)

        if (err) then
            console.log('Set BLE switch state to 0: ', err)
        end
    end)
end

function exports.test(type, ...)
    local method = exports[type]

    if (not method) then
        local names = util.keys(exports)
        table.sort(names)
        print("Available tests: " .. table.concat(names, ', '))
        return
    end

    method(...)
end

return exports
