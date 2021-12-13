--[[

Copyright 2016-2020 The Node.lua Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]
local uv = require('luv')
local lnode = require('lnode')

local meta = {
    description = "init module for lnode"
}

local exports = { meta = meta }

-- module extract

local function writeFileSync(filename, data)
    local fd = uv.fs_open(filename, "w", 438) --[[ 0666 ]]
    if fd then
        uv.fs_write(fd, data, 0)
        uv.fs_close(fd, function() end)
    end
end

local function extractLuaFiles()
    local pathname = uv.os_tmpdir() .. '/.lnode/' .. lnode.build
    local stat, err = uv.fs_stat(pathname)
    if (stat) then
        return
    end

    local filename = uv.os_tmpdir() .. '/core.' .. lnode.build .. '.zip'
    -- writeFileSync(filename, lnode.core)

    local miniz = require('miniz')
    -- local reader = miniz.createReader(filename)
    local reader = miniz.read(lnode.load('core'))
    local total = reader:getFileCount()

    -- os.remove(filename)
    if (not total) then
        return
    end

    local function saveFileData(filename, data)
        -- local script = load(data, filename)
        local script = nil
        if (script) then
            local output = string.dump(script, true)
            writeFileSync(filename, output)
        else
            writeFileSync(filename, data)
        end
    end

    local function saveFile(pathname, name, data)
        local pos = string.find(name, '/')
        if (pos) then
            pathname = pathname .. '/' .. string.sub(name, 1, pos - 1)
            uv.fs_mkdir(pathname, 511)

            name = string.sub(name, pos + 1)
            return saveFile(pathname, name, data)
        end

        filename = pathname .. '/' .. name
        pcall(saveFileData, filename, data)
    end

    local tempname = uv.os_tmpdir() .. '/.lnode/'
    uv.fs_mkdir(tempname, 511)
    -- print(tempname)

    tempname = tempname .. 'tmp'
    uv.fs_mkdir(tempname, 511)

    for i = 1, total do
        local name = reader:getFilename(i)
        local data = reader:extract(i)
        saveFile(tempname, name, data)
    end

    reader:close()
    os.rename(tempname, pathname)
    print('Extract ' .. total .. ' lua files to: ' .. pathname)
end

if (lnode.init) then
    local path = package.path
    local startIndex = 1
    local tokens = {}
    local build = lnode.build or 100

    local paths =
        '/tmp/.lnode/' .. build .. '/?.lua;' ..
        '/tmp/.lnode/' .. build .. '/?/init.lua'

    while true do
        local lastIndex = string.find(path, ';', startIndex, true)
        if (lastIndex) then
            local token = string.sub(path, startIndex, lastIndex - 1)
            if (paths and string.byte(token, 1) == 46) then -- starts with ./
                table.insert(tokens, paths)
                paths = nil
            end

            table.insert(tokens, token)
            startIndex = lastIndex + 1
        else
            table.insert(tokens, string.sub(path, startIndex))
            break
        end
    end

    package.path = table.concat(tokens, ';')
    -- package.path = paths .. package.path
    extractLuaFiles()
end

-- module loader

local function loadLocalFile(basePath, subpath)
    local path = basePath .. '?.lua;' .. basePath .. '?/init.lua'
    local filename = package.searchpath(subpath, path)
    if (filename) then
        local script, err = loadfile(filename)
        if (err) then error(err); end
        return script
    end
end

local function loadZipFile(filename, appname, subpath)
    -- console.log('loadZipFile', filename)
    local miniz = require('miniz')
    local reader = package.apps and package.apps[appname]
    if (not reader) then
        if (not filename) then
            return
        end

        local stat = uv.fs_stat(filename)
        if (not stat) then
            return
        end

        reader = miniz.createReader(filename)
        if (not reader) then
            return
        end

        if (not package.apps) then
            package.apps = {}
        end

        package.apps[appname] = reader
    end

    filename = 'lua/' .. subpath .. '.lua' -- $app/lua/$module.lua
    local data = reader:readFile(filename)
    if (not data) then
        filename = 'lua/' .. subpath .. '/init.lua' -- $app/lua/$module/init.lua
        data = reader:readFile(filename)
        if (not data) then
            return
        end
    end

    local script, err = load(data, '@$app/' .. appname .. '/' .. filename)
    if (err) then error(err); end
    return script, reader
end

package.loadZipFile = loadZipFile

local function getNodePath(name, subpath)
    if (type(name) ~= 'string') then
        return

    elseif (lnode == nil) then
        return

    elseif (name == 'lnode' or name == 'path' or name == 'fs') then
        return
    end

    local basePath = lnode.NODE_LUA_ROOT
    if (not basePath) then
        return
    end

    local stat = uv.fs_stat(basePath .. '/' .. subpath)
    if (stat == nil) then
        basePath = basePath .. '/..'
    end

    return basePath
end

local function localSearcher(name)
    if (type(name) ~= 'string') then
        return nil
    end

    local _get_script_filename = function()
        local info = debug.getinfo(3, 'Sl') or {}
        local filename = info.source or ''
        local currentline = info.currentline

        if (filename:startsWith("@")) then
            filename = filename:sub(2)
        end

        return filename, currentline or -1
    end

    local load_zip_file = function(filename)
        -- console.log('load_zip_file', filename)
        local module = package.loaded[filename]
        if (module) then
            return module
        end

        local pos = filename:find('/', 6) -- $app/appname?/lua/subpath?
        if (not pos) then
            return nil
        end

        -- console.log('filename', filename, pos)
        local appname = filename:sub(6, pos - 1)
        local subpath = filename:sub(pos + 5)

        -- console.log('load_zip_file', appname, subpath)
        local nodePath = getNodePath(name, 'app') .. '/app/' .. appname .. '.zip'
        local script = loadZipFile(nodePath, appname, subpath)
        if (script) then
            module = script()
        end

        package.loaded[filename] = module
        return module
    end

    local load_local_file = function(basePath)
        local stat = uv.fs_stat(basePath)

        local filename
        if (stat and stat.type == 'directory') then
            filename = basePath .. '/init.lua'
        else
            filename = basePath .. '.lua'
        end

        local module = package.loaded[basePath]
        if (module) then
            return module
        end

        local script, err = loadfile(filename)
        if (err) then error(err) end

        if (script) then
            module = script()
        end

        package.loaded[basePath] = module
        return module
    end

    if (name:byte(1) == 46) then -- ./?/?
        local sourcePath = _get_script_filename()
        if (not sourcePath) then
            return nil
        end

        local path = require('path')
        local basePath = path.dirname(sourcePath)
        local filename = path.join(basePath, name)

        if (filename:byte(1) == 36) then -- $app/?/lua/?
            -- console.log('filename', filename)
            return load_zip_file(filename)
        else
            return load_local_file(filename)
        end
    end
end

-- module searcher
local function moduleSearcher(name)
    local nodePath = getNodePath(name, 'modules')

    local module = name
    local subpath = 'init'
    local pos = name:find('/')
    if (pos) then
        module = name:sub(1, pos - 1)
        subpath = name:sub(pos + 1)
    end

    local basePath = nodePath .. '/modules/' .. module .. '/lua/'
    return loadLocalFile(basePath, subpath)
end

-- APP module searcher
local function appSearcher(name)
    local nodePath = getNodePath(name, 'app') -- /path/to/lnode

    local appName = name
    local subpath = 'init'
    local pos = name:find('/')
    if (pos) then
        appName = name:sub(1, pos - 1)
        subpath = name:sub(pos + 1)
    end

    local appPath = nodePath .. '/app/' .. appName
    local stat = uv.fs_stat(appPath)
    if (not stat) then
        -- zip app bundle
        return loadZipFile(appPath .. '.zip', appName, subpath)

    else
        -- path app bundle
        return loadLocalFile(appPath .. '/lua/', subpath)
    end
end

if (not package.searchers[6] ) then
    package.searchers[6] = appSearcher
    package.searchers[5] = moduleSearcher
    --package.searchers[4]
    --package.searchers[3]
    --package.searchers[2]
    --package.searchers[1]
end

-- require

if (not package.require) then
    local _require = require
    package.require = require

    local key = 'require'
    _G[key] = function(name, ...)
        if (name and name:byte(1) == 46) then -- startsWith: `.`
            return localSearcher(name)
        end

        -- print(package.loaded[name])
        return _require(name, ...)
    end
end


-- run loop

if (not _G.runLoop) then
    _G.runLoop = function(mode)
        uv.run(mode)
        uv.loop_close()
    end
end

-- process

if (not _G.process) then
    _G.process = require('process')
end

-- console

if (not _G.console) then
    _G.console = require('console')
end

-- timer

if (not _G.setTimeout) then
    local timer = require('timer')
    _G.clearImmediate = timer.clearImmediate
    _G.clearInterval = timer.clearInterval
    _G.clearTimeout = timer.clearTimeout
    _G.setImmediate = timer.setImmediate
    _G.setInterval = timer.setInterval
    _G.setTimeout = timer.setTimeout
end

return exports
