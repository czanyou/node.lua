local uv    = require('uv')
local tap   = require('ext/tap')

local isWindows = os.platform() == "win32"

-- child process 
local child_code = string.dump(function ()
    local uv = require('uv')

    -- wait 'sigint' signal
    local signal = uv.new_signal()
    uv.ref(signal)
    uv.signal_start(signal, "sigint", function ()
        print('child process signal:', signal)
        uv.unref(signal)
    end)

    uv.run()
    os.exit(7) -- exit with code 7
end)

return tap(function (test)

    test("Catch Nothing", function (print, p, expect, uv)

    end)

    if isWindows then return end

    test("Catch SIGINT", function (print, p, expect, uv)
        local child, pid
        local stdin = uv.new_pipe(false)
        local options = {
            args = {"-"},
            stdio = { stdin, 1, 2 }
        }
        
        local callback = function (code, signal)
            p("exit", {code=code, signal=signal}, {pid=pid})
            assert(code == 7)
            assert(signal == 0)
            uv.close(stdin)
            uv.close(child)
        end

        child, pid = assert(uv.spawn(uv.exepath(), options, expect(callback)))

        uv.write(stdin, child_code)
        uv.shutdown(stdin)

        -- send sigint
        local timer = uv.new_timer()
        uv.timer_start(timer, 200, 0, expect(function ()
            --print("Sending child SIGINT")
            uv.process_kill(child, "sigint")
            uv.close(timer)
        end))
    end)

end)
