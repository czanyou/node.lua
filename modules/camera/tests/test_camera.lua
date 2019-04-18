local camera = require('lcamera')
console.log(camera)

console.log(camera.type())
console.log(camera.version())

console.log(camera.init())

camera.video_in.init()

local videoIn = camera.video_in.open()
console.log(videoIn)

console.log(videoIn:get_framerate())

local options = {
    channel = 0,
    width= 640,
    height = 480
}

local videoEncoder = camera.video_encoder.open(options)
console.log(videoEncoder)

local ret, settings = videoEncoder:get_attributes()
console.log(ret, settings)

videoEncoder:start(0, function(size, data)
    console.log(size, #data)
end)
