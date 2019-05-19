pcall(require, 'script/debug')

local util = require('util')
print(util)

local ret = util.md5string('test')
print(ret)

print(arg[0]);
print(100);

