local tap = require('util/tap')
local util = require('util')
local assert = require('assert')
local lutils = require('lutils')
local test = tap.test

test("uv.guess_handle", function(expect, uv)
    local types = {
        assert(uv.guess_handle(0)),
        assert(uv.guess_handle(1)),
        assert(uv.guess_handle(2))
	}

    console.log("stdio types", table.unpack(types))
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

    console.log("memory: rss/free/total: ", rss, free, total)
end)

test("uv.uptime", function(expect, uv)
    local uptime = assert(uv.uptime())
    console.log("uptime", uptime)
end)

test("uv.getrusage", function(expect, uv)
    local rusage = assert(uv.getrusage())
    console.log("rusage.maxrss:", rusage.maxrss)
    -- console.log("rusage:", rusage)
end)

test("uv.cpu_info", function(expect, uv)
    local info = assert(uv.cpu_info())
    console.log("CPU core count: ", #info)
    assert(#info > 0)
end)

test("uv.interface_addresses", function(expect, uv)
    local addresses = assert(uv.interface_addresses())
    for name, info in pairs(addresses) do
        --console.log('interface', name, addresses[name])
        console.log("interface", name)
        --console.log('info', info)
    end
end)

test("uv.loadavg", function(expect, uv)
    local avg = { uv.loadavg() }
    console.log("loadavg", avg[1], avg[2], avg[3])
    assert(#avg == 3)
end)

test("uv.exepath", function(expect, uv)
    local exepath = assert(uv.exepath())
    console.log("exepath", exepath)
end)

test("uv.os_homedir", function(expect, uv)
    local homedir = assert(uv.os_homedir())
    console.log("homedir", homedir)
end)

test("uv.os_tmpdir", function(expect, uv)
    local tmpdir = assert(uv.os_tmpdir())
    console.log("tmpdir", tmpdir)
end)

test("uv.os_gethostname", function(expect, uv)
    local hostname = assert(uv.os_gethostname())
    console.log("hostname", hostname)
end)

test("uv.os_env_keys", function(expect, uv)
    local keys = assert(lutils.os_env_keys())
    console.log("os_env_keys", table.concat(keys, ','))
end)

test("uv.os_getenv", function(expect, uv)
    local shell = uv.os_getenv("SHELL")
    console.log("SHELL", shell)
    assert(shell)

    local path = uv.os_getenv("PATH")
    console.log("PATH", path)
    assert(path)
end)

test("uv.os_setenv", function(expect, uv)
    uv.os_setenv("TEST", "test")
    local value = assert(uv.os_getenv("TEST"))
    console.log("TEST", value)
    assert.equal(value, 'test')
end)

test("uv.os_unsetenv", function(expect, uv)
    uv.os_unsetenv("TEST")
    local path = uv.os_getenv("TEST")
    console.log("os_unsetenv", path)
    assert(not path)
end)

test("uv.cwd and uv.chdir", function(expect, uv)
    local old = assert(uv.cwd())
    -- console.log('old chdir', old)
    assert(uv.chdir("/"))
    local cwd = assert(uv.cwd())
    -- console.log("new chdir", cwd)
    assert(cwd ~= old)
    assert(uv.chdir(old))
end)

test("uv.hrtime", function(expect, uv)
    local hrtime = assert(uv.hrtime())
    console.log("hrtime", hrtime)
end)

test("test_getpid", function(expect, uv)
    local pid = uv.getpid()
    assert(pid)
    console.log('pid', pid)
end)

test("test_random", function(expect, uv)
    local ret = uv.random(32)
    console.log(#ret, util.hexEncode(ret))
    assert(#ret == 32)
end)

tap.run()
