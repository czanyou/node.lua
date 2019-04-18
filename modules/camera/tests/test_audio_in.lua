local camera = require('lcamera')
console.log(camera)

console.log(camera.type())
console.log(camera.version())

console.log(camera.init())

camera.audio_in.init()

local audioIn = camera.audio_in.open()
console.log(audioIn)

audioIn:start(function(ret, data)
    console.log(ret, #data)
end)
