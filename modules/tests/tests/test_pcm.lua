local fs = require('fs')

local filename = '/tmp/output.pcm'
local filedata = fs.readFileSync(filename)

filename = '/tmp/output.wav'

local list = {}

list[#list + 1] = "RIFF"
list[#list + 1] = string.pack("<I4", #filedata + 36)
list[#list + 1] = "WAVE"


list[#list + 1] = "fmt "
list[#list + 1] = string.pack("<I4", 16)
list[#list + 1] = string.pack("<I2I2I4I4I2I2", 1, 2, 44100, 1000, 4, 16)


list[#list + 1] = "data"
list[#list + 1] = string.pack("<I4", #filedata)
list[#list + 1] = filedata

fs.writeFileSync(filename, table.concat(list))
