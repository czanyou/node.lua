local tap = require('ext/tap')

return tap(function(test)

    test("async", function( ... )
        
    end)

-- [[

    test("test pass async between threads", function(p, p, expect, uv)
        local before = uv.uptime()
        local async = nil

        local async_callback = function (a, b, c)
            p('in async notify callback')
            --p(a, b, c)
            assert(a == 'a')
            assert(b == true)
            assert(c == 250)
            
            uv.close(async)
            async = nil
        end

        async = uv.new_async(expect(async_callback))
        --console.log('async', async)

        local args = { 500, 'string', nil, false, 5, "helloworld", async }
        local unpack = unpack or table.unpack

        local thread_func = function(num, s, null, bool, five, hw, async)
            local uv = require('uv')
            local init = require('init')

            assert(type(num) == "number")
            assert(type(s) == "string")
            assert(null == nil)
            assert(bool == false)
            assert(five == 5)
            assert(hw == 'helloworld')

            --console.log('thread async', type(async), async)

            -- 必须将 uv 添加到 package.loaded 中
            assert(type(async)=='userdata')
            uv.sleep(1200)

            assert(uv.async_send(async, 'a', true, 250) == 0)

            uv.sleep(200)
        end

        local thread = uv.new_thread(thread_func, unpack(args))
        thread:join()

        local elapsed = (uv.uptime() - before) * 1000
        assert(elapsed >= 1000, "elapsed should be at least delay ")
    end)

--]]

end)