local fs 	 = require('fs')
local path 	 = require('path')
local util   = require('util')
local app    = require('app')

local conf 	 = require('app/conf')
local uv 	 = require('uv')
local assert = require('assert')

return require('ext/tap')(function (test)
	test("test all", function (print, p, expect, uv)
		assert.equal(app.appName(), 'user')

		console.log('rootPath', app.rootPath)
		console.log('appName', app.appName())
		console.log('rootURL', app.rootURL)
		console.log('getStartFilename', app.getStartFilename())
		console.log('getStartNames', app.getStartNames())

		console.log('target', app.target())
	end)


	test("test lock", function (print, p, expect, uv)

	end)

	test("test parseName", function (print, p, expect, uv)
		assert.equal(app.parseName('lnode -d /usr/local/lnode/app/user/init.lua'), 'user')
		assert.equal(app.parseName('lnode /usr/local/lnode/bin/lpm user start'), 'user')
		assert.equal(app.parseName('lnode /lpm start user'), 'user')

		--local cmdline = 'lnode /lpm user start'
		--console.log('find', cmdline:find('lnode.+/lpm%s([%w]+)%sstart'))
	end)


end)
