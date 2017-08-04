local utils 	= require('utils')
local timer 	= require('timer')
local codec 	= require('rtsp/codec')
local core  	= require('core')
local assert 	= require('assert')
local tap 		= require('ext/tap')


return tap(function (test)

test("test table insert & remove", function ()
	console.time('test table')

	-- 测试 table 性能
	local data = "sdfklsajdfklsajdfklsjdfklsajdklgfjsadgjsakdjfklsadjfklsajdfafksajdfkljsdfkljsadkl"
	local buffer = { "test", "test"}

	for i = 1, 1000 * 1000 do
		table.insert(buffer, data)
		table.remove(buffer, 1)
	end

	console.timeEnd("test table")
end)

test("test emitter", function ()
	local test = core.Emitter:extend()
	console.time('test emitter1')

	local noop = function() end

	test:on('test', noop)
	test.noop = noop

	-- 测试 cacheListeners 性能
	for i = 1, 1000 * 1000 do
		test:emit('test', 'test')
	end
	console.timeEnd('test emitter1')

	console.time('test emitter2')

	for i = 1, 1000 * 1000 do
		--test:emit('test', 'test')
		test.noop('test')
	end
	console.timeEnd('test emitter2')

end)

end)