local tap = require("ext/tap")
local test = tap.test

test("uv.guess_handle", function(expect, uv)
    local types = {
        assert(uv.guess_handle(0)),
        assert(uv.guess_handle(1)),
        assert(uv.guess_handle(2))
	}
	
    console.log("stdio fd types: ", table.unpack(types))
end)

test("uv.version and uv.version_string", function(expect, uv)
    local version = assert(uv.version())
    local version_string = assert(uv.version_string())
    console.log{code = version, version = version_string}
    assert(type(version) == "number")
    assert(type(version_string) == "string")
end)

test("memory size", function(expect, uv)
    local rss = uv.resident_set_memory()
    local total = uv.get_total_memory()
    local free = uv.get_free_memory()
    
    assert(rss < total)
    
    console.log("memory.size: rss/free/total: ", rss, free, total)
end)

test("uv.uptime", function(expect, uv)
    local uptime = assert(uv.uptime())
    console.log{"uv.uptime:", uptime}
end)

test("uv.getrusage", function(expect, uv)
    local rusage = assert(uv.getrusage())
    console.log("rusage.maxrss:", rusage.maxrss)
end)

test("uv.cpu_info", function(expect, uv)
    local info = assert(uv.cpu_info())
    console.log("CPU core count: ", #info)
    assert(#info > 0)
end)

test("uv.interface_addresses", function(expect, uv)
    local addresses = assert(uv.interface_addresses())
    for name, info in pairs(addresses) do
        --p('interface', name, addresses[name])
        console.log("interface", name)
    --p('info', info)
    end
end)

test("uv.loadavg", function(expect, uv)
    local avg = {assert(uv.loadavg())}
    console.log("loadavg", avg[1], avg[2], avg[3])
    assert(#avg == 3)
end)

test("uv.exepath", function(expect, uv)
    local path = assert(uv.exepath())
    console.log("exepath", path)
end)

test("uv.os_homedir", function(expect, uv)
    local path = assert(uv.os_homedir())
    console.log("os_homedir", path)
end)

test("uv.os_tmpdir", function(expect, uv)
    local path = assert(uv.os_tmpdir())
    console.log("os_tmpdir", path)
end)

test("uv.os_gethostname", function(expect, uv)
    local path = assert(uv.os_gethostname())
    console.log("os_gethostname", path)
end)

test("uv.os_getenv", function(expect, uv)
    local path = assert(uv.os_getenv("PATH"))
    console.log("os_getenv", path)
end)

test("uv.os_setenv", function(expect, uv)
    uv.os_setenv("TEST", "TEST")
    local path = assert(uv.os_getenv("TEST"))
    p("os_setenv", path)
end)

test("uv.os_unsetenv", function(expect, uv)
    uv.os_unsetenv("TEST")
    local path = uv.os_getenv("TEST")
    console.log("os_unsetenv", path)
end)

test("uv.cwd and uv.chdir", function(expect, uv)
    local old = assert(uv.cwd())
    --p('old chdir', old)
    assert(uv.chdir("/"))
    local cwd = assert(uv.cwd())
    console.log("new chdir", cwd)
    assert(cwd ~= old)
    assert(uv.chdir(old))
end)

test("uv.hrtime", function(expect, uv)
    local time = assert(uv.hrtime())
    console.log("hrtime", time)
end)

test("test_getpid", function(expect, uv)
    assert(uv.getpid())
end)

tap.run()
