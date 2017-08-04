local tap = require('ext/tap')


return tap(function (test)

    -- This tests using timers for a simple timeout.
    -- It also tests the handle close callback and
    test("simple timeout", function (print, p, expect, uv)
        local timer = uv.new_timer()
        local function onClose()
            p("closed", timer)
        end

        local function onTimeout()
            p("timeout", timer)
            uv.close(timer, expect(onClose))
        end
        uv.timer_start(timer, 10, 0, expect(onTimeout))
    end)

    -- This is like the previous test, but using repeat.
    test("simple interval (3 times)", function (print, p, expect, uv)
        local timer = uv.new_timer()
        local count = 3

        local onClose = expect(function ()
            p("closed", timer)
        end)

        local function onInterval()
            p("interval", timer)
            count = count - 1
            if count == 0 then
                uv.close(timer, onClose)
            end
        end

        uv.timer_start(timer, 10, 10, onInterval)
    end)

    -- Test two concurrent timers
    -- There is a small race condition, but there are 50ms of wiggle room.
    -- 250ms is halfway between 2x100ms and 3x100ms
    test("timeout with interval (2 times)", function (print, p, expect, uv)
        local a = uv.new_timer()
        local b = uv.new_timer()
        uv.timer_start(a, 250, 0, expect(function ()
            p("timeout", a)
            uv.timer_stop(b)
            uv.close(a)
            uv.close(b)
        end))

        uv.timer_start(b, 100, 100, expect(function ()
            p("interval", b)
        end, 2))
    end)

    -- This advanced test uses the rest of the uv_timer_t functions
    -- to create an interval that shrinks over time.
    test("shrinking interval (4 times)", function (print, p, expect, uv)
        local timer = uv.new_timer()
        uv.timer_start(timer, 10, 0, expect(function ()
            local r = uv.timer_get_repeat(timer)
            p("interval", timer, r)
            if r == 0 then
                uv.timer_set_repeat(timer, 8)
                uv.timer_again(timer)

            elseif r == 2 then
                uv.timer_stop(timer)
                uv.close(timer)

            else
                uv.timer_set_repeat(timer, r / 2)
            end
        end, 4))
    end)

    test("shrinking interval using methods (4 times)", function (print, p, expect, uv)
        local timer = uv.new_timer()
        local timeout = 10
        timer:start(timeout, 0, expect(function()
            local r = timer:get_repeat()
            p("interval", timer, r)

            if r == 0 then
                timer:set_repeat(8)
                timer:again()

            elseif r == 2 then
                timer:stop()
                timer:close()

            else
                timer:set_repeat(r / 2)
            end
        end, 4))
    end)

end)
