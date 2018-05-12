--[[

Copyright 2016 The Node.lua Authors. All Rights Reserved.

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

local meta = {}
meta.name        = "lnode/assert"
meta.version     = "1.0.1"
meta.license     = "Apache 2"
meta.tags        = { "lnode", "assert", "test" }
meta.description = "Provides a simple set of assertion tests that can be used to test invariants."

-------------------------------------------------------------------------------
-- Assertion Testing

-- The assert module provides a simple set of assertion tests that can be used to test invariants.
local exports = { meta = meta }

-- Tests for deep equality between the actual and expected parameters.
function exports.deepEqual(actual, expected, message)
    local ret, defaultMessage = exports.isDeepEqual(actual, expected)
    if (not ret) then
        error(message or defaultMessage or 'is deep equal')
    end

    return true
end

function exports.equal(actual, expected, message)
    if (actual == expected) then
        return true
    end

    local newActual   = tonumber(actual)
    local newExpected = tonumber(expected)
    if (newActual ~= nil) and (newActual == newExpected) then
        return true
	end

    exports.fail(actual, expected, message, '==')
end

function exports.fail(actual, expected, message, operator)
    local list = {}
    list[#list + 1] = (message or '')
    list[#list + 1] = ' Expected '
    list[#list + 1] = tostring(operator or '')
    list[#list + 1] = ' ['
    list[#list + 1] = tostring(expected)
    list[#list + 1] = '], but is ['
    list[#list + 1] = tostring(actual)
    list[#list + 1] = '] '
	error(table.concat(list))
end

function exports.ifError(value)
    if (value) then
        error(tostring(value))
    end
end

function exports.isDeepEqual(actual, expected, path)
    if expected == actual then
        return true
    end

    local prefix = path and (path .. ": ") or ""
    local expectedType = type(expected)
    local actualType = type(actual)
    if expectedType ~= actualType then
        return false, prefix .. "Expected type " .. expectedType .. " but found " .. actualType
    end

    if expectedType ~= "table" then
        return false, prefix .. "Expected " .. tostring(expected) .. " but found " .. tostring(actual)
    end

    local expectedLength = #expected
    local actualLength = #actual
    for key in pairs(expected) do
        if actual[key] == nil then
            return false, prefix .. "Missing table key " .. key
        end

        local newPath = path and (path .. '.' .. key) or key
        local same, message = exports.isDeepEqual(actual[key], expected[key], newPath)
        if not same then
            return same, message
        end
    end

    if expectedLength ~= actualLength then
        return false, prefix .. "Expected table length " .. expectedLength .. " but found " .. actualLength
    end

    for key in pairs(actual) do
        if expected[key] == nil then
            return false, prefix .. "Unexpected table key " .. key
        end
    end

    return true
end

function exports.notDeepEqual(actual, expected)
	local ret, message = exports.isDeepEqual(actual, expected)
	if (ret) then
		error(message or 'not deep equal')
	end

    return true
end

function exports.notEqual(actual, expected, message)
    if (actual == expected) then
        exports.fail(actual, expected, message, '!=')
    end

    local newActual   = tonumber(actual)
    local newExpected = tonumber(expected)
    
    if (newActual ~= nil) and (newActual == newExpected) then
        exports.fail(actual, expected, message, '!=')
    end

    return true
end

function exports.ok(value, message)
    if (not value) then
        exports.fail(value, 'true', message, 'is')
    end

    return value -- assert() must return the value when assert ok
end

setmetatable(exports, {
    __call = function(self, ...)
        return self.ok(...)
    end
})

return exports
