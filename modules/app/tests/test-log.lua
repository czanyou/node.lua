local log  = require('app/log')
local tap    = require('util/tap')
local assert = require('assert')

log.init()

describe('test log', function()
    console.info('test console.info', 1)
    console.warn('test console.warn', 2)
    console.error('test console.error', 3)
end)
