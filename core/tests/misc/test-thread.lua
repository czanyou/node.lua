local thread = require('thread')
local fs = require('fs')
local printr = console.printr

local tap = require('util/tap')
local test = tap.test

test("main", function()
    local printr = console.printr

    printr("main:", thread.self())
end)

test("thread", function()
    local thr = thread.start(function(a, b, c)
        local printr = console.printr
        local thread = require('thread')
        local fs = require('fs')

        assert(a + b == c)
        print(string.format("%d+%d=%d", a, b, c))
        printr("child", thread.self())

        local fd = assert(fs.openSync("thread.tmp", "w+"))
        fs.writeSync(fd, 0, tostring(thread.self()))
        assert(fs.closeSync(fd))
	end, 2, 4, 6)

    local id = tostring(thr)
    thr:join()

    local chunk = fs.readFileSync("thread.tmp")
    printr(chunk, id)
    assert(chunk == id)
    fs.unlinkSync("thread.tmp")
end)

test("threadpool", function()
    local work = thread.work(function(n)
        local thread = require('thread')

        local self = tostring(thread.self())
        return self, n, n * n
    end,
    function(id, n, r)
        print(id, n, r)
        console.log("work result cb", id, n * n == r)
    end)

    thread.queue(work, 2)
    thread.queue(work, 4)
    thread.queue(work, 6)
    thread.queue(work, 8)
    thread.queue(work, 2)
    thread.queue(work, 4)
    thread.queue(work, 6)
    thread.queue(work, 8)
end)

tap.run()
