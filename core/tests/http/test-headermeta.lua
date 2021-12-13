local headerMeta = require('http').headerMeta

local tap = require('util/tap')
local test = tap.test

test("Set via string", function()
    local headers = setmetatable({}, headerMeta)
    headers.Game = "Monkey Ball"
    headers.Color = "Many"
    --console.log(headers)
    assert(#headers == 2)
    assert(headers.game == "Monkey Ball")
    assert(headers.color == "Many")
end)

test("Set via append", function()
    local headers = setmetatable({}, headerMeta)
    headers[#headers + 1] = {"Game", "Monkey Ball"}
    headers[#headers + 1] = {"Color", "Many"}
    --console.log(headers)
    assert(#headers == 2)
    assert(headers.game == "Monkey Ball")
    assert(headers.color == "Many")
end)

test("Replace header", function()
    local headers = setmetatable({}, headerMeta)
    headers.Game = "Monkey Ball"
    headers.Game = "Ultimate"
    --console.log(headers)
    assert(#headers == 1)
    assert(headers.game == "Ultimate")
end)

test("Duplicate Keys", function()
    local headers = setmetatable({}, headerMeta)
    headers[#headers + 1] = {"Skill", "Network"}
    headers[#headers + 1] = {"Skill", "Compute"}
    --console.log(headers)
    assert(#headers == 2)
    assert(headers[1][2] == "Network")
    assert(headers[2][2] == "Compute")
    assert(headers.skill == "Network" or headers.skill == "Compute")
end)

test("Remove Keys", function()
    local headers = setmetatable({
        {"Color", "Blue"},
        {"Color", "Red"},
        {"Color", "Green"},
    }, headerMeta)
    --console.log(headers)
    assert(#headers == 3)
    headers.color = nil
    --console.log(headers)
    assert(#headers == 0)
end)

test("Replace Keys", function()
    local headers = setmetatable({
        {"Color", "Blue"},
        {"Color", "Red"},
        {"Color", "Green"},
    }, headerMeta)
    --console.log(headers)
    assert(#headers == 3)
    headers.Color = "Orange"
    --console.log(headers)
    assert(#headers == 1)
    assert(headers.Color == "Orange")
end)

test("Replace Keys with Keys", function()
    local headers = setmetatable({
        {"Color", "Blue"},
        {"Color", "Red"},
        {"Color", "Green"},
    }, headerMeta)
    --console.log(headers)
    assert(#headers == 3)
    headers.Color = {"Orange", "Purple"}
    --console.log(headers)
    assert(#headers == 2)
    assert(headers[1][2] == "Orange")
    assert(headers[2][2] == "Purple")
end)

test("Large test", function()
    local headers = setmetatable({
        {"Game", "Monkey Ball"},
        {"Game", "Ultimate"},
        {"Skill", "Network"},
        {"Skill", "Compute"},
        {"Color", "Blue"},
        {"Color", "Red"},
        {"Color", "Green"},
    }, headerMeta)
    headers.Why = "Because"
    --console.log(headers)
    assert(#headers == 8)
    if headers.cOLOR then
        headers.Color = "Many"
    end
    if headers.gAME then
        headers.Game = "Yes"
    end
    --console.log(headers)
    assert(#headers == 5)
    assert(headers.game == "Yes")
    assert(headers.color == "Many")
    assert(headers.why == "Because")
end)

tap.run()
