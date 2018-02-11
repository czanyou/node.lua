local lmedia = require('lmedia')
local li2c   = require('lmedia.i2c')
local utils  = require('utils')

--console.log(lmedia)
local delay = lmedia.delay

local I2C_SLAVE   		= 1795
local I2C_ADDRESS 		= 0x40 -- SHT21 Address

local CMD_SOFT_RESET  	= 0xFE
local CMD_TEMPERATURE 	= 0xF3
local CMD_HUMIDITY    	= 0xF5

local i2c, err = li2c.open('/dev/i2c-1')
console.log('open', i2c, err)

if (i2c) then
	local ret, err = i2c:setup(0, 0)
	console.log('setup', ret, err)

	local ret, err = i2c:read(2)
	console.log('read', ret, err)

	local ret, err = i2c:setup(I2C_SLAVE, I2C_ADDRESS)
	console.log('setup', ret, err)

	local ret, err = i2c:write(string.char(CMD_SOFT_RESET))
	console.log('write', ret, err)
	delay(50)  -- ms

	local ret, err = i2c:write(string.char(CMD_TEMPERATURE))
	console.log('write', ret, err)
	delay(200) -- ms

	local ret, err = i2c:read(3)
	console.log('read', ret, err)

	local ret, err = i2c:crc(string.char(0xff, 0x44))
	console.log('crc', ret, err)

end

run_loop()

