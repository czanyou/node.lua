local tap = require('util/tap')
local test = tap.test

test("simple prepare", function(expect, uv)
    local prepare = uv.new_prepare()
    uv.prepare_start(prepare, expect(function()
        console.log("prepare", prepare)
        uv.prepare_stop(prepare)
        uv.close(prepare, expect(
            function()
        end))
    end))
end)

test("simple check", function(expect, uv)
    local check = uv.new_check()
    uv.check_start(check, expect(function()
        console.log("check", check)
        uv.check_stop(check)
        uv.close(check, expect(
            function()
        end))
    end))

    -- Trigger with a timer
    local timer = uv.new_timer()
    uv.timer_start(timer, 10, 0, expect(function()
        console.log("timeout", timer)
        uv.timer_stop(timer)
        uv.close(timer)
    end))
end)

test("simple idle", function(expect, uv)
    local idle = uv.new_idle()
    uv.idle_start(idle, expect(function()
        console.log("idle", idle)
        uv.idle_stop(idle)
        uv.close(idle, expect(function() end))
    end))
end)

test("simple async", function(expect, uv)
    local async
    async = uv.new_async(expect(function()
        uv.close(async)
    end))

    uv.async_send(async)
end)

tap.run()
