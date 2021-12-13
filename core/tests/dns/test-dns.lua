--[[

Copyright 2014 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]
local dns = require("dns")
local assert = require('assert')

-- Appveyor is failing builds randomly... need to re-enable
if os.getenv("APPVEYOR") then
    return
end

local tap = require('util/tap')
local test = tap.test

test("localhost", function(expect)
    dns.resolve4("localhost", expect(function(err, answers)
        if (err) then console.log(err) end
        --assert(not err)
        --assert(#answers > 0)
        console.log(err, answers)
    end))
end)

test("resolve4", function(expect)
    dns.resolve4("luvit.io", expect(function(err, answers)
        if (err) then console.log(err) end
        assert(not err)
        assert(#answers > 0)
        console.log(answers)
    end))
end)

test("lookup", function(expect)
    dns.lookup("luvit.io", expect(function(err, answers)
        if (err) then console.log(err) end
        assert(not err)
        assert(#answers > 0)
        console.log(answers)
    end))
end)

--[[
test("resolve6", function(expect)
    dns.resolve6("luvit.io", expect(function(err, answers)
        if (err) then console.log(err) end
        assert(not err)
        console.log(answers)
        assert(#answers > 0)
    end))
end)

test("resolve6", function(expect)
    dns.resolve6("luvit.io", expect(function(err, answers)
        if (err) then console.log(err) end
        assert(not err)
        console.log(answers)
        assert(#answers > 0)
    end))
end)

test("resolveSrv", function(expect)
    dns.resolveSrv("_https._tcp.luvit.io", expect(function(err, answers)
        if (err) then console.log(err) end
        assert(not err)
        console.log(answers)
        assert(#answers > 0)
    end))
end)

test("resolveMx", function(expect)
    dns.resolveMx("luvit.io", expect(function(err, answers)
        if (err) then console.log(err) end
        assert(not err)
        console.log(answers)
        assert(#answers > 0)
    end))
end)

test("resolveNs", function(expect)
    dns.resolveNs("luvit.io", expect(function(err, answers)
        if (err) then console.log(err) end
        assert(not err)
        console.log(answers)
        assert(#answers > 0)
    end))
end)

test("resolveCname", function(expect)
    dns.resolveCname("try.luvit.io", expect(function(err, answers)
        if (err) then console.log(err) end
        assert(not err)
        console.log(answers)
        assert(#answers > 0)
    end))
end)

test("resolveTxt", function(expect)
    dns.resolveTxt("google._domainkey.luvit.io", expect(function(err, answers)
        if (err) then console.log(err) end
        assert(not err)
        console.log(answers)
        assert(#answers > 0)
    end))
end)

test("resolveTxtTimeout", function(expect)
    dns.setServers({{["host"] = "127.0.0.1", ["port"] = 53234}})
    dns.setTimeout(200)
    dns.resolveTxt("google._domainkey.luvit.io", expect(function(err, answers)
        if (err) then console.log(err) end
        assert(err)
    end))
end)

test("resolveTxtTCP", function(expect)
    dns.setTimeout(2000)
    dns.setServers({{["host"] = "8.8.8.8", ["port"] = 53, ["tcp"] = true}})
    dns.resolveTxt("google._domainkey.luvit.io", expect(function(err, answers)
        if (err) then console.log(err) end
        assert(not err)
    end))
end)
--]]

test("bad address", function(expect)
    dns.resolve4("luvit.not_a_domain", expect(function(err)
        if (err) then console.log(err) end
        assert(err)
        assert(err.code > 0)
    end))
end)


tap.run()
