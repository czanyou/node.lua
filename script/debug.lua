-- path
local path = package.path
path = path .. ';' .. string.gsub(path, '?.lua', 'core/lua/?.lua')
package.path = path

-- cpath
local cpath = package.cpath
local newCPath = string.gsub(cpath, '?.dll', 'bin/?.dll')
newCPath = newCPath .. ';' .. string.gsub(cpath, '?.dll', 'bin/nodelua.dll')
package.cpath = newCPath

require('init')
