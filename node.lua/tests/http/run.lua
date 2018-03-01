local tap 	= require("ext/tap")
local uv  	= require("uv")
local utils = require('util')

tap.testAll(utils.dirname())
