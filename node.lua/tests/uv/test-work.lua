local uv = require('uv')
local tap = require('ext/tap')

return tap(function(test)

    test("test uv.new_work", function()
        print('Please be patient, the test cost a lots of time')
        local count     = 1000 -- for memleaks dected
        local step      = 0
        local worker    = nil

        -- after work, in loop thread
        local callback = function(n, r, id, s)
            assert(n * n == r)

            if (step < count) then
                uv.queue_work(worker, n, s)

                step = step + 1
                
                if (step % 100 == 0) then
                    print(string.format('run %d%%', math.floor(step * 100 / count)))
                end
            end
        end    

        -- work, in threadpool
        local work = function(n, s) 
            local uv = require('uv')
            local threadId = uv.thread_self()

            uv.sleep(1)
            return n, n * n, tostring(threadId), s
        end

        worker = uv.new_work(work, callback)

        local longString = string.rep('-', 4096)

        local list = { 2, 4, 6, -2, -11, 2, 4, 6, -2, -11 }
        for _, value in ipairs(list) do
            uv.queue_work(worker, value, longString)
        end
        
    end)

end)
