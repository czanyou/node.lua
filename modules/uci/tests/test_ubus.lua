local uloop = require('uloop')
console.log(uloop)

local lubus = require('lubus')
console.log(lubus)

uloop.init()

local conn = ubus.connect()

console.log(conn)

console.log(ubus.INT32)

uloop.run()
