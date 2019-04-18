local wot = require('wot')

local ret = wot.fetch('http://localhost/9100/things/gateway')

--console.log(ret)

ret:next(function(data)
    console.log('test')
    console.log(data)
    return data

end):next(function(next)
    console.log('next')
    console.log(next)
    
end):catch(function(data)
    console.log('catch', data)
end)

--console.log(ret)

setTimeout(1000, function() end)
