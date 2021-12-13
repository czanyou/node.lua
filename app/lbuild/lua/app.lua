local app 		= require('app')
local util 		= require('util')
local path  	= require('path')
local fs  		= require('fs')
local exec      = require('child_process').exec

local build  	= require('./build')
local sdk  	    = require('./sdk')
local update    = require('./update')

local cwd		= process.cwd()

-------------------------------------------------------------------------------
-- exports

local exports = {}

function exports.app(name)
	local target = sdk.getMakeTarget()
	local nodePath  = sdk.getSDKBuildPath(target)
	sdk.buildApp(name, path.join(nodePath, 'app', name))
end

function exports.deb(...)
	-- sdk.buildDebPackage(...)
	local target = sdk.getMakeTarget()
	local packageInfo = sdk.buildSDK(target)

	local sdk_name = "nodelua-" .. target .. "-sdk"
	local deb_name = "nodelua-" .. target
	local sdk_path  = path.join(cwd, "/build/", sdk_name)
	local deb_path  = path.join(cwd, "/build/", deb_name .. "-deb")

	-- deb files
	fs.mkdirpSync(deb_path .. '/')
	os.execute('rm -rf ' .. deb_path .. '/usr/local/lnode/*')
	os.execute('cp -rf ' .. sdk_path .. '/* ' .. deb_path .. '/usr/local/lnode/')

	-- deb meta files
	local dirname = util.dirname()
	local src = path.join(dirname, 'targets/linux/deb')
	os.execute('cp -rf ' .. src .. '/* ' .. deb_path .. '/')
	os.execute('chmod -R 755 ' .. deb_path .. '/DEBIAN')

	-- build deb package
	local deb_file = path.join(cwd, "/build/", deb_name .. ".deb")
    local cmd = 'dpkg -b ' .. deb_path .. ' ' .. deb_file
    local options = { timeout = 30 * 1000, env = process.env }
    exec(cmd, options, function(err, stdout, stderr)
        print(stderr or (err and err.message) or stdout)
	end)

	print(console.colorize("success", 'Finished!'))
end

function exports.sdk(...)
	sdk.buildPackage("sdk", ...)
end

function exports.tar(...)
	local target = sdk.getMakeTarget()
	local packageInfo = sdk.buildPackage(target)

	-- build tar.gz file
	local name = "nodelua-" .. target .. "-sdk"
    local cmd = "cd build/" .. name .. "; tar -zcvf ../" .. name .. ".tar.gz *"
    os.execute(cmd)

    print('Builded: "build/' .. name .. '.tar.gz".')
	print(console.colorize("success", 'Finished!'))
end

function exports.version()
	local file = io.popen("svn info --xml", "r")
	if nil == file then
		return print("open pipe for svn fail")
	end

	local content = file:read("*a")
	if nil == content then
		return print("read pipe for svn fail")
	end

	local xml = require('app/xml')
	local parser = xml.newParser()
	local document = parser:parseXmlText(content)
	if nil == document then
		return print("parse xml for svn fail")
	end

	local children = document:children();
	local root = children and children[1]
	_, root = xml.xmlToTable(root)

	local entry = root and root.entry
	local commit = entry and entry.commit
	local reversion = commit and commit['@revision']
	if nil == reversion then
		return print("parse reversion for svn fail")
	end

	print('reversion: ' .. reversion)
	if (reversion) then
		local data = 'local exports = { build = ' .. reversion .. '}\nreturn exports\n'
		fs.writeFileSync('core/lua/@version.lua', data)
	end
end

function exports.help()
	print([[

Node.lua SDK and application build tools

usage: lbuild <command> [args]

- help    Display help information
- sdk	  Build Node.lua SDK package (Must `make <target>` firist)

- config  	
- get     
- restart 
- set     
- update  

please execute this APP by the Makefile.

]])

	print("Current make target is: " .. sdk.getMakeTarget())
	print("")
end

function exports.core()
	build.build()
end

function exports.lua()
	build.build()
end

function exports.test()
	build.test()
end

-------------------------------------------------------------------------------
-- install

exports.config = update.config
exports.get = update.get
exports.restart = update.restart
exports.set = update.set
exports.update = update.update

app(exports)
