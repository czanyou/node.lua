local tap 	    = require("ext/tap")
local utils     = require('utils')
local path      = require('path')
local assert    = require('assert')
local sqlite3   = require('sqlite3')
local data      = require('sqlite3/data')


tap(function(test)

test("open_data", function()
	local db = data.open(":memory:")
	--console.log(db)

	db:init()

	db:add('humidity', 1234)
	db:add('humidity', 1235)
	db:add('humidity', 1236)

	db:add(1002, 4567)
	db:add(1003, 890)

	local list = db:list('humidity')
	--console.log('list', list)


	local latest = db:latest(1002)
	--console.log('latest', latest)

	local list = db:find({'humidity'}, 'week')
	--console.log('list', list)

	local list = db:find({'humidity', 'humidity.min', 'humidity.max'}, 'week')
	console.log('list', list)	

	local list = db:stat_list('humidity')
	console.log('list', #list)	
end)

end)