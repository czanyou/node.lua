local tap  = require('util/tap')
local util = require('util')

local dirname = util.dirname()
console.log('dirname', dirname);
tap.testAll(dirname)
