local tap 	= require("ext/tap")
local uv  	= require("uv")
local utils = require("utils")

tap.testAll(utils.dirname())
