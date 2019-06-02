package.path = '/usr/local/lnode/lua/?.lua;/usr/local/lnode/lua/?/init.lua;/usr/local/lnode/lib/?.lua;/usr/local/lnode/lib/?/init.lua;' .. package.path 
package.cpath = '/usr/local/lnode/bin/?.so;/usr/local/lnode/lib/?.so;' .. package.cpath

require('init')
