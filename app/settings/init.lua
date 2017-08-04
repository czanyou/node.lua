local app 		= require('app')

local exports = {}

function exports.help()
    print([[

Node.lua settings application
  
usage: This APP only used via httpd.app
  
    ]])
end

app(exports)
