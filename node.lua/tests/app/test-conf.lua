local fs 	 = require('fs')
local path 	 = require('path')
local utils  = require('util')
local tap    = require('ext/tap')

local conf 	 = require('app/conf')
local uv 	 = require('uv')
local assert = require('assert')

local test = tap.test

test("test profile:load", function ()
	local text = [[
	{
		"test" : {
			"name" : "lucy"
		},
		"video" : {
			"w" : 100,
			"a" : true,
			"b" : false,
			"h" : 200
		}
	}

	]]

	local filename = "test_load.conf"
	local profile = conf.Profile:new(filename)
	profile:load(text)

	--print(profile:toString())	
	assert.equal(profile:get(nil), nil)
	assert.equal(profile:get(''), nil)
	assert.equal(profile:get("video.none"), nil)
	assert.equal(profile:get("video.w"), 100)
	assert.equal(profile:get("video.h"), 200)
	assert.equal(profile:get("video.a"), true)
	assert.equal(profile:get("video.b"), false)
	assert.equal(profile:get("test.name"), "lucy")

	local video = profile:get("video")
	assert.equal(video.w, 100)
	assert.equal(video.h, 200)
	assert.equal(video.a, true)
	assert.equal(video.b, false)
	assert.equal(video.none, nil)
end)

test("test profile:set", function ()
	local text = '{}'

	local func  	= function() end
	local object 	= { func = func, func }
	local array 	= { func, func, func}
	local thread 	= coroutine.create(func)
	local userdata 	= uv.new_thread(func)

	local filename = "test_set.conf"
	local profile = conf.Profile:new(filename)
	profile:load(text)

	-- 测试不同类型的值
	profile:set("test.name", 		"gigi")
	profile:set("test.int", 		400)
	profile:set("test.float", 		400.1)
	profile:set("test.true", 		true)
	profile:set("test.false", 		false)
	profile:set("test.nil", 		'v')
	profile:set("test.nil", 		nil)
	profile:set("test.object", 		object)
	profile:set("test.array", 		array)
	profile:set("test.function", 	func)
	profile:set("test.thread", 		thread)
	profile:set("test.userdata", 	userdata)

	profile:commit(function()
		print("assert get")
		--print(profile:toString())	

		assert.equal(profile:get("test.name"), 		"gigi")
		assert.equal(profile:get("test.int"), 		400)
		assert.equal(profile:get("test.float"), 	400.1)
		assert.equal(profile:get("test.true"), 		true)
		assert.equal(profile:get("test.false"), 	false)
		assert.equal(profile:get("test.nil"), 		nil)
		assert.equal(profile:get("test.object.func"), 	tostring(func))
		assert.equal(profile:get("test.function"), 	tostring(func))
		assert.equal(profile:get("test.thread"), 	tostring(thread))
		assert.equal(profile:get("test.userdata"), 	tostring(userdata))

		os.remove(profile.filename)
	end)
end)

test("test profile:set name type", function ()
	local filename = "test.conf"
	local profile = conf.Profile:new(filename)
	profile:load("{}")

	local table 	= {}
	local func  	= function() end
	local thread 	= coroutine.create(function() end)
	local userdata 	= uv.new_thread(function() end)
	
	-- 测试不同类型的参数名类型
	profile:set(nil, 'v')
	profile:set('test', 'v')
	profile:set(1, 'v')
	profile:set(0, 'v')
	profile:set(true, 'v')
	profile:set(table, 'v')
	profile:set(false, 'v')
	profile:set(func, 'v')
	profile:set(thread, 'v')
	profile:set(userdata, 'v')

	--print(profile:toString())

	assert.equal(profile:get(nil), nil)
	assert.equal(profile:get('test'), 'v')
	assert.equal(profile:get(1), 'v')
	assert.equal(profile:get(0), 'v')
	assert.equal(profile:get(true), 'v')
	assert.equal(profile:get(table), 'v')
	assert.equal(profile:get(false), 'v')
	assert.equal(profile:get(func), 'v')
	assert.equal(profile:get(thread), 'v')
	assert.equal(profile:get(userdata), 'v')
end)

test("test profile conf", function ()
	local profile = conf('network')
	console.log(profile)
end)

tap.run()

