local util  = require('util')
local gpio  = require('devices/hal/gpio')

local await = util.await

local pin = arg[1] or 40
local out = arg[2] or 0

local ret, err = util.async(function()

	local gpio0 = gpio(pin)
	console.log(gpio0)

	--assert(false, 'test assert')

	local err = await(gpio0.open, gpio0)
	--assert(false, 'test assert')

	--console.log('err', err)
	assert(false, err)

	local err, value = await(gpio0.direction, gpio0, 'out')
	assert(not err, err)
	print('direction', value)

	local err, value = await(gpio0.read, gpio0)
	assert(not err, err)
	print('read', value)

	local err = await(gpio0.write, gpio0, out)
	assert(not err, err)

	local err, value = await(gpio0.read, gpio0)
	assert(not err, err)
	print('read', value)

	local err = await(gpio0.close, gpio0)
	assert(not err, err)	
end)

if (err) then
	error(err)
end
