local tap = require('util/tap')
local test = tap.test

test("Get all local http addresses", function(expect, uv)
    assert(uv.getaddrinfo(nil, "http", nil, expect(function(err, res)
        console.log(#res, res[1])
        assert(not err, err)
        assert(res[1].port == 80)
    end)))
end)

test("Get all local http addresses sync", function(expect, uv)
    local res = assert(uv.getaddrinfo(nil, "http"))
    console.log(#res, res[1])
    assert(res[1].port == 80)
end)

test("Get only ipv4 tcp adresses for baidu.com", function(expect, uv)
    local options = { socktype = "stream", family = "inet" }
    assert(uv.getaddrinfo("baidu.com", nil, options, expect(function(err, res)
        assert(not err, err)
        console.log(#res, res[1])
        assert(#res >= 1)
    end)))
end)

if _G.isWindows then
    test("Get only ipv6 tcp adresses for baidu.com", function(expect, uv)
        local options = { socktype = "stream", family = "inet6" }
        assert(uv.getaddrinfo("baidu.com", nil, options, expect(function(err, res)
            assert(not err, err)
            console.log(res, #res)
            assert(#res == 1)
        end)))
    end)
end

test("Get ipv4 and ipv6 tcp adresses for baidu.com", function(expect, uv)
    assert(uv.getaddrinfo("baidu.com", nil, { socktype = "stream"}, expect(function(err, res)
        assert(not err, err)
        -- console.log(res, #res)
        assert(#res > 0)
        console.log(#res, res[1])
    end)))
end)

test("Get all adresses for baidu.com", function(expect, uv)
    assert(uv.getaddrinfo("baidu.com", nil, nil, expect(function(err, res)
        assert(not err, err)
        --console.log(res, #res)
        assert(#res > 0)
        console.log(#res, res[1])
    end)))
end)

test("Lookup local ipv4 address", function(expect, uv)
    assert(uv.getnameinfo({family = "inet"}, expect(function(err, hostname, service)
        console.log{err = err, hostname = hostname, service = service}
        assert(not err, err)
        assert(hostname)
        assert(service)
    end)))
end)

test("Lookup local ipv4 address sync", function(expect, uv)
    local hostname, service = assert(uv.getnameinfo({family = "inet"}))
    console.log{hostname = hostname, service = service}
    assert(hostname)
    assert(service)
end)

test("Lookup local 127.0.0.1 ipv4 address", function(expect, uv)
    assert(uv.getnameinfo({ip = "127.0.0.1"}, expect(function(err, hostname, service)
        console.log{err = err, hostname = hostname, service = service}
        assert(not err, err)
        assert(hostname)
        assert(service)
    end)))
end)

test("Lookup local ipv6 address", function(expect, uv)
    assert(uv.getnameinfo({family = "inet6"},expect(function(err, hostname, service)
        console.log{err = err, hostname = hostname, service = service}
        assert(not err, err)
        assert(hostname)
        assert(service)
    end)))
end)

test("Lookup local ::1 ipv6 address", function(expect, uv)
    assert(uv.getnameinfo({ip = "::1"}, expect(function(err, hostname, service)
        console.log{err = err, hostname = hostname, service = service}
        assert(not err, err)
        assert(hostname)
        assert(service)
    end)))
end)

test("Lookup local port 80 service", function(expect, uv)
    assert(uv.getnameinfo({port = 80, family = "inet6"}, expect(function(err, hostname, service)
        console.log{err = err, hostname = hostname, service = service}
        assert(not err, err)
        assert(hostname)
        assert(service == "http")
    end)))
end)

tap.run()
