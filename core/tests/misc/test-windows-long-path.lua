--[[

Copyright 2012-2015 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License")
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]
local tap = require('util/tap')
local test = tap.test

test("fs windows long path", function()
    local __dirname = os.tmpdir

    if os.platform() ~= "win32" then
        return
    end

    local Path = require('path')
    -- test the win32 long path logic

    console.log("-- simple case")
    local dirtmp = Path.join(__dirname, "tmp")
    local long_expected = "\\\\?\\" .. dirtmp
    console.log("dirtmp=" .. dirtmp)
    console.log("makeLong=" .. Path._makeLong(dirtmp))
    console.log("expected=" .. long_expected)
    assert(long_expected == Path._makeLong(dirtmp))

    console.log("-- derelativize with a trailing .")
    local dirtmp = Path.join(__dirname, "tmp\\.")
    local long_expected = "\\\\?\\" .. Path.join(__dirname, "tmp")
    console.log("dirtmp=" .. dirtmp)
    console.log("makeLong=" .. Path._makeLong(dirtmp))
    console.log("expected=" .. long_expected)
    assert(long_expected == Path._makeLong(dirtmp))

    console.log("-- derelativize with a trailing ..")
    local dirtmp = Path.join(__dirname, "tmp\\..")
    local long_expected = "\\\\?\\" .. __dirname:gsub("/", "\\")
    console.log("dirtmp=" .. dirtmp)
    console.log("makeLong=" .. Path._makeLong(dirtmp))
    console.log("expected=" .. long_expected)
    assert(long_expected == Path._makeLong(dirtmp))

    console.log("-- derelativize with a middle .")
    local dirtmp = Path.join(__dirname, ".\\tmp")
    local long_expected = "\\\\?\\" .. Path.join(__dirname, "tmp")
    console.log("dirtmp=" .. dirtmp)
    console.log("makeLong=" .. Path._makeLong(dirtmp))
    console.log("expected=" .. long_expected)
    assert(long_expected == Path._makeLong(dirtmp))

    console.log("-- derelativize with multiple middle .")
    local dirtmp = Path.join(__dirname, ".\\.\\.\\tmp")
    local long_expected = "\\\\?\\" .. Path.join(__dirname, "tmp")
    console.log("dirtmp=" .. dirtmp)
    console.log("makeLong=" .. Path._makeLong(dirtmp))
    console.log("expected=" .. long_expected)
    assert(long_expected == Path._makeLong(dirtmp))

    console.log("-- derelativize with a middle ..")
    local dirtmp = Path.join(__dirname, "tmp\\bar\\..\\foo")
    local long_expected = "\\\\?\\" .. Path.join(__dirname, "tmp\\foo")
    console.log("dirtmp=" .. dirtmp)
    console.log("makeLong=" .. Path._makeLong(dirtmp))
    console.log("expected=" .. long_expected)
    assert(long_expected == Path._makeLong(dirtmp))

    console.log("-- derelativize with a trailing x, testing for properly escaped . (as %.) in path code")
    local dirtmp = Path.join(__dirname, "tmp\\x")
    local long_expected = "\\\\?\\" .. Path.join(__dirname, "tmp\\x")
    console.log("dirtmp=" .. dirtmp)
    console.log("makeLong=" .. Path._makeLong(dirtmp))
    console.log("expected=" .. long_expected)
    assert(long_expected == Path._makeLong(dirtmp))

    console.log("-- derelativize with a trailing xx, testing for properly escaped .. (as %.%.) in path code")
    local dirtmp = Path.join(__dirname, "tmp\\xx")
    local long_expected = "\\\\?\\" .. Path.join(__dirname, "tmp\\xx")
    console.log("dirtmp=" .. dirtmp)
    console.log("makeLong=" .. Path._makeLong(dirtmp))
    console.log("expected=" .. long_expected)
    assert(long_expected == Path._makeLong(dirtmp))

    console.log("-- derelativize with a middle x, testing for properly escaped . (as %.) in path code")
    local dirtmp = Path.join(__dirname, "x\\tmp")
    local long_expected = "\\\\?\\" .. Path.join(__dirname, "x\\tmp")
    console.log("dirtmp=" .. dirtmp)
    console.log("makeLong=" .. Path._makeLong(dirtmp))
    console.log("expected=" .. long_expected)
    assert(long_expected == Path._makeLong(dirtmp))

    console.log("-- derelativize with a middle xx, testing for properly escaped .. (as %.%.) in path code")
    local dirtmp = Path.join(__dirname, "tmp\\bar\\xx\\foo")
    local long_expected = "\\\\?\\" .. Path.join(__dirname, "tmp\\bar\\xx\\foo")
    console.log("dirtmp=" .. dirtmp)
    console.log("makeLong=" .. Path._makeLong(dirtmp))
    console.log("expected=" .. long_expected)
    assert(long_expected == Path._makeLong(dirtmp))

    console.log("-- derelativize with multiple middle ..")
    local dirtmp = Path.join(__dirname, "tmp\\bar\\..\\..\\foo")
    local long_expected = "\\\\?\\" .. Path.join(__dirname, "foo")
    console.log("dirtmp=" .. dirtmp)
    console.log("makeLong=" .. Path._makeLong(dirtmp))
    console.log("expected=" .. long_expected)
    assert(long_expected == Path._makeLong(dirtmp))

    console.log("-- derelativize with combination .. and .")
    local dirtmp = Path.join(__dirname, "tmp\\.\\bar\\..\\..\\foo\\.\\..\\horse\\.")
    local long_expected = "\\\\?\\" .. Path.join(__dirname, "horse")
    console.log("dirtmp=" .. dirtmp)
    console.log("makeLong=" .. Path._makeLong(dirtmp))
    console.log("expected=" .. long_expected)
    assert(long_expected == Path._makeLong(dirtmp))

    console.log("-- derelativize past the drive root")
    local dirtmp = "c:\\..\\..\\..\\tmp\\.\\bar\\..\\..\\foo\\.\\..\\horse\\."
    local long_expected = "\\\\?\\c:\\horse"
    console.log("dirtmp=" .. dirtmp)
    console.log("makeLong=" .. Path._makeLong(dirtmp))
    console.log("expected=" .. long_expected)
    assert(long_expected == Path._makeLong(dirtmp))
end)

tap.run()
