local fs 	 = require('fs')
local path 	 = require('path')
local util   = require('util')
local app    = require('app')
local upgrade    = require('app/upgrade')

local conf 	 = require('app/conf')
local uv 	 = require('uv')
local assert = require('assert')

return require('ext/tap')(function (test)
	test("test all", function ()
		console.log('isDevelopmentPath', upgrade.isDevelopmentPath())

		console.log('nodePath', upgrade.nodePath)


	end)

	test("test parseVersion", function ()
		assert.equal(upgrade.parseVersion(nil), 0)
		assert.equal(upgrade.parseVersion('1.2.3'), 100020003)
		assert.equal(upgrade.parseVersion('1.0.3'), 100000003)
		assert.equal(upgrade.parseVersion('0.0.3'), 3)
		assert.equal(upgrade.parseVersion('0.2.3'), 20003)
	end)

	test("test updater", function ()
		local filename = util.dirname() .. '/data/update.zip'
		local rootPath = os.tmpdir .. '/update'

		local options = {
			filename = filename,
			rootPath = rootPath
		}

		local updater = upgrade.openUpdater(options)

		updater.reader = upgrade.openBundle(filename)
		--updater.list = {}

		local packageInfo = updater:parsePackageInfo()
		console.log('packageInfo', packageInfo)

		updater:checkAllFiles()

		console.log(updater)

		updater:updateAllFiles(function( err )
			console.log(err, updater)
		end)
	end)

end)
