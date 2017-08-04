local data = 'cpu  417696 0 84136 35050851 18063 0 2461 0 0 0'
local utils     = require('utils')
local pprint = utils.pprint
local d = string.gmatch(data,"%d+")
local TotalCPUtime = 0;
local x = {}
local i = 1
for w in d do
    TotalCPUtime = TotalCPUtime + w
    x[i] = w
    i = i +1
end
print(TotalCPUtime)
local TotalCPUusagetime = 0;
pprint(x)
TotalCPUusagetime = x[1]+x[2]+x[3]+x[6]+x[7]+x[8]+x[9]+x[10]
print(TotalCPUusagetime)
local percent = TotalCPUusagetime/TotalCPUtime
print(percent)