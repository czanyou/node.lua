local snapshot = require("snapshot")
local json = require('json')

local indentation = require("util/snapshot").indentation

local S1 = snapshot()

-- [[
local tmp = {
    player = {
        uid = 1,
        camps = {
            {campid = 1},
            {campid = 2},
        },
    },
    player2 = {
        roleid = 2,
    },
    [3] = {
        player1 = 1,
    },
}

--]]

local a = {}
local c = {}
a.b = c
c.d = a

local msg = "bar"
local foo = function()
    print(msg)
end

local co = coroutine.create(function ()
    print("hello world")
end)

collectgarbage()
local S2 = snapshot()

local function getDiff(s1, s2)
    local diff = {}
    for k,v in pairs(s2) do
        if not s1[k] then
            diff[k] = v
        end
    end

    return diff
end

local diff = getDiff(S1, S2)
console.log(diff)

print("===========================")

local result = indentation(diff)
console.log(result)

--[[
local list = {}
for k, v in pairs(S2) do
    table.insert(list, tostring(k) .. '=' .. v)
end

print(table.concat(list, '\r\n'))
--]]