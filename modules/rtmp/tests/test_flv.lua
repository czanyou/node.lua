local fs = require('fs')
local rtmp = require('rtmp')
local assert = require('assert')

local exports = {}
local flv = rtmp.flv

local function loadFlv()
    local filepath = 'test.flv'

    local fileData = fs.readFileSync(filepath)
    console.log('filesize', #fileData)

    local index = 1
    local tag = nil

    -- file header
    index = rtmp.flv.parseFileHeader(fileData, index)
    --console.log(index)

    local tagData = nil

    -- tags
    local tags = {}
    tags[#tags + 1] = tagData

    while (true) do
        -- video
        if (index > #fileData - 8) then
            console.log('end', index, #fileData - 8)
            break
        end

        index, tag = flv.parseTagHeader(fileData, index)
        local tagData = fileData:sub(index, index + tag.tagSize - 1);
        if (not tagData) then
            break
        end

        tag.data = tagData
        -- console.log('tag', index, tag)

        if (tag.tagType == 0x09) then
            local result = flv.decodeVideoTag(tagData)
            -- console.log(result)

            tags[#tags + 1] = tag

        elseif (tag.tagType == 0x08) then
            local result = flv.decodeAudioTag(tagData)
            --console.log(result)

        elseif (tag.tagType == 0x12) then
            local result = flv.decodeMetadataTag(tagData)
            -- console.log(result)

            tags[#tags + 1] = tag
        end

        index = index + tag.tagSize
    end

    return tags
end

local function saveFlv(tags)
    local filePath = 'output.flv'
    os.remove(filePath)
    os.remove('image.jpg')

    local stream = fs.createWriteStream(filePath)
    stream:on('finish', function()
        console.log('finish');

        local cmdline = 'ffmpeg -y -i output.flv -ss 00:00:00 -vframes 1 -f image2 -s 640x360 image.jpg'
        local ret, err = os.execute(cmdline)
        console.log('ret', ret, err);
    end)

    local fileHeader = flv.encodeFileHeader()
    stream:write(fileHeader)

    local lastTagSize = 0

    local metadata = tags[1]
    if (metadata.data) then
        local tagData = metadata.data
        local tagSize = #tagData

        -- metadata tag
        local header = flv.encodeTagHeader(0x12, tagSize, lastTagSize)
        stream:write(header)
        stream:write(tagData)
        lastTagSize = tagSize
    end

    for i = 2, 3 do
        local video = tags[i]
        local tagData = video.data
        local tagSize = #tagData
        local tagTime = video.timestamp

        console.log(i, tagTime, tagSize);

        -- video tag
        local header = flv.encodeTagHeader(0x09, tagSize, lastTagSize, tagTime)
        stream:write(header)
        stream:write(tagData)
        lastTagSize = tagSize
    end

    stream:finish()
end

-- 测试 encodeVideoConfiguration & decodeVideoTag
local function test_flv()
    local sps = 'aaaaaaa'
    local pps = '1111111'
    local data = flv.encodeVideoConfiguration(sps, pps)
    console.printBuffer(data)

    local result = flv.decodeVideoTag(data)
    console.log(result)

    assert.equal(result.sps, sps)
    assert.equal(result.pps, pps)
end

test_flv()


local tags = loadFlv()
console.log('tags.size', #tags)

saveFlv(tags);
