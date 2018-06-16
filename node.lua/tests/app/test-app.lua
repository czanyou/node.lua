local fs 	 = require('fs')
local path 	 = require('path')
local util   = require('util')
local app    = require('app')
local tap    = require('ext/tap')

local conf 	 = require('app/conf')
local uv 	 = require('uv')
local assert = require('assert')

local test = tap.test

test("test all", function ()
	
	assert.equal(app.appName(), 'user')

	console.log('rootPath', app.rootPath)
	console.log('appName', app.appName())

	console.log('target', app.target())
end)


test("test lock", function ()

end)

test("test parseName", function ()
	assert.equal(app.parseName('lnode -d /usr/local/lnode/app/user/lua/app.lua'), 'user')
	assert.equal(app.parseName('lnode /usr/local/lnode/bin/lpm user start'), 'user')
	assert.equal(app.parseName('lnode /lpm start user'), 'user')

	--local cmdline = 'lnode /lpm user start'
	--console.log('find', cmdline:find('lnode.+/lpm%s([%w]+)%sstart'))
end)


tap.run()

