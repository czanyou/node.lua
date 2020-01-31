-- Port of https://github.com/rhysbrettbowen/promise_impl/blob/master/promise.js
-- and https://github.com/rhysbrettbowen/Aplus

-- The Promise object represents the eventual completion (or failure) of an
-- asynchronous operation, and its resulting value.

local State = {
    PENDING   = 'pending',
    FULFILLED = 'fulfilled',
    REJECTED  = 'rejected',
}

local passthrough = function(x) return x end
local errorthrough = function(x) error(x) end

local function is_callable_table(callback)
    local mt = getmetatable(callback)
    return type(mt) == 'table' and type(mt.__call) == 'function'
end

local function is_callable(value)
    local t = type(value)
    return t == 'function' or (t == 'table' and is_callable_table(value))
end

local transition, resolve, run

---@class Promise
---@field public isPromise boolean
---@field public state string
local Promise = {
    isPromise = true,
    state = State.PENDING
}

Promise.mt = { __index = Promise }

-- 异步执行指定的函数
---@param callback function 要异步执行的函数
local do_async = function(callback)
    setTimeout(0, callback)
end

local reject = function(promise, reason)
    transition(promise, State.REJECTED, reason)
end

local fulfill = function(promise, value)
    transition(promise, State.FULFILLED, value)
end

-- 设置指定的 promise 的状态和值
---@param promise Promise
---@param state string
---@param value any
-- 只能从 pending 状态到 fulfilled/rejected
-- 一旦状态确定将不可再改变
transition = function(promise, state, value)
    if promise.state == state
        or promise.state ~= State.PENDING
        or ( state ~= State.FULFILLED and state ~= State.REJECTED )
        or value == nil
    then
        return
    end

    promise.state = state
    promise.value = value
    run(promise)
end

-- 进入 resolve 状态
---@param promise Promise
---@param x Promise|any
resolve = function(promise, x)
    if promise == x then
        reject(promise, 'TypeError: cannot resolve a promise with itself')
        return
    end

    local x_type = type(x)

    --
    if x_type ~= 'table' then
        fulfill(promise, x)
        return
    end

    -- x is a promise in the current implementation
    if x.isPromise then
        -- 2.3.2.1 if x is pending, resolve or reject this promise after completion
        if x.state == State.PENDING then
            x:next(function(value)
                resolve(promise, value)
            end,
            function(reason)
                reject(promise, reason)
            end)

            return
        end

        -- if x is not pending, transition promise to x's state and value
        transition(promise, x.state, x.value)
        return
    end

    local called = false
    -- 2.3.3.1. Catches errors thrown by __index metatable
    local success, reason = pcall(function()
        local next = x.next
        if is_callable(next) then
            next(x, function(y)
                if not called then
                    resolve(promise, y)
                    called = true
                end
            end, function(r)
                if not called then
                    reject(promise, r)
                    called = true
                end
            end)
        else
            fulfill(promise, x)
        end
    end)

    if not success then
        if not called then
            reject(promise, reason)
        end
    end
end

run = function(promise)
    if promise.state == State.PENDING then
        return
    end

    do_async(function()
        while true do
            local obj = table.remove(promise.queue, 1)
            if not obj then
                break
            end

            local success, result = pcall(function()
                local success = obj.fulfill or passthrough
                local failure = obj.reject or errorthrough
                local callback = (promise.state == State.FULFILLED) and success or failure
                return callback(promise.value)
            end)

            if not success then
                reject(obj.promise, result)
            else
                resolve(obj.promise, result)
            end
        end
    end)
end

-- Create a new promise
---@param callback fun(resolve:function, reject:function) end
-- We call resolve(...) when what we were doing asynchronously was successful
-- and reject(...) when it failed.
function Promise.new(callback)
    local instance = {
        queue = {}
    }

    setmetatable(instance, Promise.mt)

    if callback then
        callback(function(value)
            resolve(instance, value)
        end, function(reason)
            reject(instance, reason)
        end)
    end

    return instance
end

-- ----------------------------------------------------------------------------
-- methods

-- Appends fulfillment and rejection handlers to the promise, and returns a new
-- promise resolving to the return value of the called handler, or to its
-- original settled value if the promise was not handled (i.e. if the relevant
-- handler onFulfilled or onRejected is not a function).
---@param onFulfilled fun(value:any):any
---@param onRejected fun(reason:any)
function Promise:next(onFulfilled, onRejected)
    local promise = Promise.new()

    table.insert(self.queue, {
        fulfill = is_callable(onFulfilled) and onFulfilled or nil,
        reject = is_callable(onRejected) and onRejected or nil,
        promise = promise
    })

    run(self)

    return promise
end

-- Appends a rejection handler callback to the promise, and returns a new
-- promise resolving to the return value of the callback if it is called, or
-- to its original fulfillment value if the promise is instead fulfilled.
---@param onRejected fun(reason:any)
function Promise:catch(onRejected)
    return self:next(nil, onRejected)
end

-- Returns a new Promise object that is resolved with the given value.
function Promise:resolve(value)
    fulfill(self, value)
end

-- Returns a new Promise object that is rejected with the given reason.
function Promise:reject(reason)
    reject(self, reason)
end

-- ----------------------------------------------------------------------------
-- static methods

-- resolve when all promises complete
-- Wait for all promises to be resolved, or for any to be rejected.
---@vars {promise}
---@return {promise}
function Promise.all(...)
    local promises = {...}
    local results = {}
    local state = State.FULFILLED
    local remaining = #promises

    local promise = Promise.new()

    local check_finished = function()
        if remaining > 0 then
            return
        end
        transition(promise, state, results)
    end

    for i,p in ipairs(promises) do
        p:next(function(value)
            results[i] = value
            remaining = remaining - 1
            check_finished()

        end, function(value)
            results[i] = value
            remaining = remaining - 1
            state = State.REJECTED
            check_finished()
        end)
    end

    check_finished()

    return promise
end

-- resolve with first promise to complete
-- Wait until any of the promises is resolved or rejected.
function Promise.race(...)
    local promises = {...}
    local promise = Promise.new()

    Promise.all(...):next(nil, function(value)
        reject(promise, value)
    end)

    local success = function(value)
        fulfill(promise, value)
    end

    for _,p in ipairs(promises) do
        p:next(success)
    end

    return promise
end

return Promise
