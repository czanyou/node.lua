local util = require('util')
local tap = require('util/tap')

local rtmp = require("rtmp")

local amf0 = rtmp.amf0

describe('test rtmp message', function()
    --
    local message = '020000000000040500000000004c4b40'
    local data = util.hex2bin(message);
    local header, body = rtmp.parseChunk(data)
    console.log('parse', header, body)

    --
    message = '0300000000001d14000000000200075f726573756c7400400000000000000005003ff0000000000000'
    data = util.hex2bin(message);
    header, body = rtmp.parseChunk(data)
    console.log('parse', header, body)

    --
    message = '0300000000007314010000000200086f6e537461747573000000000000000000050300056c6576656c0200067374617475730004636f64650200144e657453747265616d2e506c61792e5265736574000b6465736372697074696f6e02001d506c6179696e6720616e6420726573657474696e672073747265616d2e000009'
    data = util.hex2bin(message);

    header, body = rtmp.parseChunk(data)
    console.log('parse', header, body)

    --
    message = '0300000000006d14010000000200086f6e537461747573000000000000000000050300056c6576656c0200067374617475730004636f64650200144e657453747265616d2e506c61792e5374617274000b6465736372697074696f6e0200175374617274656420706c6179696e672073747265616d2e000009'
    data = util.hex2bin(message);

    header, body = rtmp.parseChunk(data)
    console.log('parse', header, body)

    --
    message = '0600000000001812000000000200117c52746d7053616d706c6541636365737301000100'
    data = util.hex2bin(message);

    header, body = rtmp.parseChunk(data)
    console.log('parse', header, body)

    --
    message = '0200000000000401000000000000ea60'
    data = util.hex2bin(message);

    header, body = rtmp.parseChunk(data)
    console.log('parse', header, body)

    --
    message = '0300000000006d14010000000200086f6e537461747573000000000000000000050300056c6576656c0200067374617475730004636f64650200144e657453747265616d2e506c61792e5374617274000b6465736372697074696f6e0200175374617274656420706c6179696e672073747265616d2e000009'
    message = message .. '0300000000007314010000000200086f6e537461747573000000000000000000050300056c6576656c0200067374617475730004636f64650200144e657453747265616d2e506c61792e5265736574000b6465736372697074696f6e02001d506c6179696e6720616e6420726573657474696e672073747265616d2e000009'
    data = util.hex2bin(message);

    header, body = rtmp.parseChunk(data)
    console.log('parse', header, body)

    --
    local index = header.headerSize + header.messageLength
    header, body = rtmp.parseChunk(data, index + 1)
    console.log('parse', header, body, index)
end)

describe('test rtmp message', function()
    local list = { 'play', 0, amf0.null, 'test' }

    local body = rtmp.amf0.encodeArray(list)
    local header = rtmp.encodeChunkHeader(#body)
    local data = header .. body

    console.printBuffer(data)
    header, body = rtmp.parseChunk(data)
    console.log('parse', header, body)

    header = rtmp.flv.encodeFileHeader();
    console.printBuffer(header)

    local tag = rtmp.flv.encodeTagHeader(0x09, 100, 0)
    console.printBuffer(tag)
end)

describe('test rtmp message', function()
    local MESSAGE = rtmp.MESSAGE
    console.log(MESSAGE)

    local array = { 'releaseStream', 2, amf0.null, 'test' }
    local message = rtmp.encodeCommandMessage(array)
    console.printBuffer(message)

    array = { 'FCPublish', 3, amf0.null, 'test' }
    message = rtmp.encodeCommandMessage(array)
    console.printBuffer(message)

    array = { 'createStream', 4, amf0.null }
    message = rtmp.encodeCommandMessage(array)
    console.printBuffer(message)

    message = rtmp.encodeControlMessage(MESSAGE.SET_CHUNK_SIZE, 1360)
    console.printBuffer(message)

    console.log('WINDOW_ACKNOWLEDGEMENT_SIZE')
    local options = { fmt = 0x00, chunkStreamId = 0x02, messageStreamId = 0x00 }
    message = rtmp.encodeControlMessage(MESSAGE.WINDOW_ACKNOWLEDGEMENT_SIZE, 5000000, options)
    console.printBuffer(message)

    console.log('publish')
    array = { 'publish', 5, amf0.null, 'test', 'live' }
    local options = { fmt = 0x00, chunkStreamId = 0x04 }
    message = rtmp.encodeCommandMessage(array, options)
    console.printBuffer(message)

    local header, body = rtmp.parseChunk(message, 1)
    console.log('publish', header, body)

    array = { '@setDataFrame', 'onMetaData', {
        copyright = 'EasyRTMP',
        width = 1280,
        height = 720,
        framerate = 0,
        videocodecid = 7,
        audiosamplerate = 8000,
        audiocodecid = 10
    } }

    local options = { fmt = 0x00, chunkStreamId = 0x04 }
    message = rtmp.encodeDataMessage(array, options)
    console.log('@setDataFrame', message)
    console.printBuffer(message)

    local result, body = rtmp.parseChunk(message, 1)
    console.log(result, body)

    local nalu = '1700000000014d001fffe10018674d001f9da814016e9b808080a00000030020000005108001000468ee3c80'
    nalu = util.hex2bin(nalu)

    local options = { fmt = 0x00, chunkStreamId = 0x04 }
    message = rtmp.encodeVideoMessage(nalu, options)
    console.log('nalu', message)
    console.printBuffer(message)

    --local header, body = rtmp.parseChunk(message, 1)
end)

describe('test rtmp message', function()
    local data = string.pack('<I4>I4', 1, 1)
    console.log(data);
    console.printBuffer(data);

    console.log(process.hrtime() // 1000000);
end)
