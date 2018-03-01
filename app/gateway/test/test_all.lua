
local beacon = {
	MAC         = 'AC:23:3F:31:01:6E', 
    Major       = 10022, 
    Manufacture = '4C 00 ', 
    Minor       = 35756, 
    Rssi        = -59, 
    TxPower     = {-89,-74,-81,-92,-77,-89,-92,-91,-77,-90}
}

-- local result = maxminize(beacon.TxPower)
-- print(result)
-- result = average(beacon.TxPower)
-- print(result)
-- result = exports.distance(beacon)
-- print(result)

local ibeacon = require("ibeacon")
console.log(ibeacon)

local string = "12345678901234567890"
local mac = ibeacon.parseMACAddress(string, 10)
console.log(mac)

