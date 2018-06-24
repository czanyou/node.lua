local utils  = require('app/utils')
local tap    = require('ext/tap')
local assert = require('assert')

local test = tap.test

test("test formatBytes", function ()
	assert.equal(utils.formatBytes(0), '0 Bytes')
	assert.equal(utils.formatBytes(nil), nil)
	assert.equal(utils.formatBytes('test'), nil)
	assert.equal(utils.formatBytes(true), nil)

	assert.equal(utils.formatBytes(1024), '1.0 KBytes')
	assert.equal(utils.formatBytes(1024 * 1024), '1.0 MBytes')
	assert.equal(utils.formatBytes(1024 * 1024 * 1024), '1.0 GBytes')
end)

test("test formatFloat", function ()
	assert.equal(utils.formatFloat(0), '0.0')
	assert.equal(utils.formatFloat(nil), nil)
	assert.equal(utils.formatFloat('test'), nil)
	assert.equal(utils.formatFloat(true), nil)


	assert.equal(utils.formatFloat(3.1415), '3.1')
	assert.equal(utils.formatFloat(3.1415, 3), '3.142')


end)


test("test getSystemTarget", function ()
	console.log('getSystemTarget', utils.getSystemTarget())
end)

test("test table", function ()
	local cols = {8, 6, 4}
	local table = utils.table(cols)

	print(table.title('test'))
	print(table.line())
	print(table.cell(1, 2, 3))
	print(table.cell())
	print(table.line())

end)

tap.run()
