local app      = require('app')
local path     = require('path')
local fs       = require('fs')

local exports = {}

-- The PATCH version
exports.version = 200


-- 配置文件名
function exports.getStartFilename()
    local tmpdir = os.tmpdir
	return path.join(tmpdir, 'lhost.conf')
end

-- 返回所有需要后台运行的应用
function exports.getStartNames()
    local filedata = fs.readFileSync(exports.getStartFilename())
    local names = {}
    local count = 0

    if (not filedata) then
        return names, count, filedata
    end

    local list = filedata:split("\n")
    for _, item in ipairs(list) do
        if (#item > 0) then
            local filename = path.join(exports.rootPath, 'app', item)
            if fs.existsSync(filename) then
                names[item] = item
                count = count + 1
            end
        end
    end
    
    return names, count, filedata
end


-- 启用/禁用指定的应用后台进程
function exports.enable(newNames, enable)
    local names, count, oldData = exports.getStartNames()

    for _, name in ipairs(newNames) do
        if (enable) then
            local filename = path.join(exports.rootPath, 'app', name)
            if (fs.existsSync(filename)) then
                names[name] = name
            end

        else
            names[name] = nil
        end
    end
    
    -- save to file
    local list = {}
    for _, item in pairs(names) do
        list[#list + 1] = item
    end

    table.sort(list, function(a, b)
        return tostring(a) < tostring(b)
    end)

    list[#list + 1] = ''
    local fileData = table.concat(list, "\n")   
    if (oldData == fileData) then
        return fileData
    end

    print("Updating process list...")
    print("  " .. table.concat(list, " ") .. "\n")

    local filename = exports.getStartFilename()

    local tempname = filename .. ".tmp"
    local ret, err = fs.writeFileSync(tempname, fileData)
    if (err) then 
    	console.log(err)
    	return
    end

    os.remove(filename)
    os.rename(tempname, filename)

    return fileData
end

return exports

