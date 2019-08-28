local uv = require('luv')
local thread = require('thread')
local rpc = require('app/rpc')

local callback = nil

local async_callback = function (event, b, c)
    console.log(event, b, c)

    if (event == 'callback') then
        callback = b
    end
end

local async = uv.new_async(async_callback)
--console.log('async', async)


local thread_func = function(num, s, null, bool, five, hw, async)
    local uv = require('luv')
    local rpc = require('app/rpc')

    local handler = {}
    local name = 'modbus'

    function handler:test(...)
        console.log(...)
        return 1000;
    end

    rpc.server(name, handler, function(event, error, result)
        console.log(event, error, result)
    end)

    console.log(num, s, null, bool, five, hw, async)

    setInterval(1000, function()
        -- console.log('timer 1')
        uv.async_send(async, 'timer', true, 250)
    end)
end

local args = { 500, 'string', nil, false, 5, "helloworld", async }
local thread = thread.start(thread_func, table.unpack(args))
console.log(thread)

setInterval(2000, function()
    -- console.log('timer 2')
    rpc.call('modbus', 'test', { 100, 200 }, function(error, result)
        console.log('result', error, result)
    end)
end)
