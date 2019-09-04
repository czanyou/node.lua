local app    = require('app')
local tap    = require('ext/tap')
local assert = require('assert')

local test = tap.test

test("test all", function ()
	assert.equal(app.appName(), 'user')

	console.log('rootPath', app.rootPath)
	console.log('nodePath', app.nodePath)
	console.log('appName', app.appName())
	console.log('target', app.getSystemTarget())
end)

test("test lock", function ()

end)

test("test parseName", function ()
	assert.equal(app.parseName('lnode -d /usr/local/lnode/app/user/lua/app.lua'), 'user')
	assert.equal(app.parseName('lnode /usr/local/lnode/bin/lpm user start'), 'user')
	assert.equal(app.parseName('lnode /lpm start user'), 'user')

	
	assert.equal(app.parseName('lnode -d /usr/local/lnode/v4.6.226/app/gateway/lua/app.lua start'), 'gateway')
	--local cmdline = 'lnode /lpm user start'
	--console.log('find', cmdline:find('lnode.+/lpm%s([%w]+)%sstart'))

	console.log(app.parseName('lnode -d /usr/local/lnode/v4.6.226/app/lci/lua/app.lua start'))
	console.log(app.parseName('lnode -d /usr/local/lnode/v4.6.226/app/lpm/lua/app.lua run'))
end)


tap.run()

