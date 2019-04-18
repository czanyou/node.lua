local util = require('util')

local exports = {}

exports.encodeFileHeader = function()
    local flags = 0x05
    local headerSize = 9
    return string.pack(">BBBBI4", 0x46, 0x4c, 0x56, 0x01, flags, headerSize)
end

exports.encodeTagHeader = function(isVideo, tagSize, preTagSize, timestamp)
    local tagType = 0x08
    local timestamp = 0x00 -- 毫秒
    local timestampEx = 0x00
    local streamId = 0x00

    if (isVideo) then
        tagType = 0x09
    end

    return string.pack(">I4BI3I3B", preTagSize, tagType, tagSize, timestamp, timestampEx, streamId)
end

return exports