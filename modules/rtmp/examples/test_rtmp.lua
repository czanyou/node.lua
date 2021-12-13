local net = require('net')
local util = require('util')
local rtmp = require("rtmp")
local fs = require('fs')

local amf0 = rtmp.amf0;

local client = nil;

local state = 0

local function sendC0C1()
    local c0c1 = '035c41de3100000000249f942f5c3acbd1d355495627a42ca1bf0f7aa2a872e77bd7e052a47f74d18c226cac67907f476ac57ab1d62dcf86d5c70f7e7e7275ea515c43e6c4a8bf58b33a132ab37b5a2d48bdcf2ddba59cc07b9c4deb15abdc570f2f45c4c0ed2b832e2896d38cd90fbda6c7d3887c7e4fe82186da2840c66838de96e6a592182fb229b68ca7978c6b4c5a4ec5c7bd24b7d09398e1bc6550e652d8dbe171e41f3215c7a7ad653a27a2865e6e5c2b7b1ae41da4cccb182bc05412a2446d8d54909322474778725821e1a78145bbe550a612dd81c6df9e8d42993e6f15b4ac8f4fc0bf7f3f38c04a2977b45f39a898d1a385597873e8149e893b1c8fd9b9253780d59fa9156fe42fcf9f7717561ed1eb8c3a6af0297095a394a2427c63509ccc354b843ba36f53811dbb895dc2624f5e8daa55a721d45aa77d852ad1c6b0a5e4e4302696916a26972c98ddd8eb3b3d7fcf7b36e15e798fcdefaba5bc6a59a85d7bbfdc133111934692802d8da45b1382c03a732d9c11eb92a5a05e16e2155c64bd4768df41e52dc5744b591f905d935f81ef7d2ce970b09e1715a5e2131156c141afa874a3c6481e188a2f99d8abe160a9667ea1c73546c73bd5b83fcf1de91fb6a0846075b5707f4e881f2e3a107fd467e67c352ab4ed4e90ac7e6ebb777e781eecc985b040ede8b91b1de41485bf6c7b4b8a8ee886ce874253e6e6bb6b6dcb6645571e7753ef37571b235d91cbb2131d4c9314bb6884e6ac71d36fc64f413b7e8142debd401c23442869bfe523c311605d0f22b67c106adfd4c2b43312d89a842a8750538c5c81a6b74f9acb19943268943d25203e78e82249a33e448ac9b19d57eadacc566a8114a222c8aca0e31b432f324c5f933b6acecf99196169bcefa9b5d0841249ef17dc18c890a9ba9cd6d3bf29395a5694372c34397e86e67536ab54a3a687a1af6aab7eeb5b4897402a5d5b4ca8a2d1c8bfee114583e0aba292e854487edfe8da9175ccdda66a2db9b979146822ce38cacb321e5521b2e8a5aa4cde2f3acd10bc49cea0e147bea1e93ea759497c822357a52a9db7c68d6377c25097ed2c99b05f6e5f4f9e25d9975487e18f136a9b5b16aee1be837531eb466a8a428032dbd0914a263e60f0be9d87a6338b17b7cf1e75b7cee13ce8d473616d9fca8889a920bcc04723c0efb24ea4d6caad9da0b4196691e39380c616cb3aa6a4b3365dbce4241316d511b9329e97e5523b94163dec902f8618e78dd4283a7fc562c5904ddb8c54bf8615db3495c76fc16b6eef5ef02dd50f1b6ad4358d5aebd82f8234191e72c19578a3b21c7a29c6ce88bc3b7fda177fdf6a5a1be9a6efd0c680eed0876f9824d84bc7ddb6d9aa937175b7d95eb7684431b35021604eda35b8d7ee4e55966334ca32188f1ab3297437c95d7f87aeb4a970eeb3ba439de0ec83d642c27396e74cb9e9ccbdabde40d4b68e5a44431ddf9d12996647454d3ab2326d8396ed71d3ad69a6791c93abd95040428675486c214cee707c43aea7ded21c706f18ca52b63be137487cd328b51a5b4278949782d195e354c999edb67a102dd219e02bb82a1ce05b89ba7445beb879455c1fb134a59b7a75436e3aa66f50887140a43053a9209839c3137090bddabf20e27f459721a81b56253fe57d8074d7b12817eeba2095e5d49964746545427636aaa5b6bc5cc3196bebf0d17a6bb83384b83046c9ae3aa4568727a5b55222dcedb09ab11464bb705eb250c92d0fe59ab01cd188bb123c198a4caf4e90ba328472b5447728e9d877aa2f47c0283c62c9494259143e7e16b1bbaee952772ac8dac81b60e1133f67a758977671c4c94915138b12421819dcc5b8d41e36e7d718bee469aee0921c96dba5145b70c68d76c22871ed297bd9df3abce762b3cd6b80b8bd36a856434540d14284511821b0cb3231c84c95b033b97b292a35e77ea7a742ce5e8a188cbbd3c04f33c959cc9b7ce672b18329d54b8eef5eb4decd6a941e3fdb99417664233d9c3fefe61a9a69ea13297c26e8b0a5e61d68cbdbbc66e2e4488334a8d048d67b78d5687c76c26d7ad4d291cb913db99f978b815ae36a4d3ade73d3bda4b13f2c9598911a61ef7d45d0161f7044c116c45c802d4ed36471c1c84c857beeb6908a5d308da8'
    local message = util.hex2bin(c0c1)
    console.log('sendC0C1', #message)
    client:write(message)
end

local function sendC2()
    local c2 = '5c41de3100000000249f942f5c3acbd1d355495627a42ca1bf0f7aa2a872e77bd7e052a47f74d18c226cac67907f476ac57ab1d62dcf86d5c70f7e7e7275ea515c43e6c4a8bf58b33a132ab37b5a2d48bdcf2ddba59cc07b9c4deb15abdc570f2f45c4c0ed2b832e2896d38cd90fbda6c7d3887c7e4fe82186da2840c66838de96e6a592182fb229b68ca7978c6b4c5a4ec5c7bd24b7d09398e1bc6550e652d8dbe171e41f3215c7a7ad653a27a2865e6e5c2b7b1ae41da4cccb182bc05412a2446d8d54909322474778725821e1a78145bbe550a612dd81c6df9e8d42993e6f15b4ac8f4fc0bf7f3f38c04a2977b45f39a898d1a385597873e8149e893b1c8fd9b9253780d59fa9156fe42fcf9f7717561ed1eb8c3a6af0297095a394a2427c63509ccc354b843ba36f53811dbb895dc2624f5e8daa55a721d45aa77d852ad1c6b0a5e4e4302696916a26972c98ddd8eb3b3d7fcf7b36e15e798fcdefaba5bc6a59a85d7bbfdc133111934692802d8da45b1382c03a732d9c11eb92a5a05e16e2155c64bd4768df41e52dc5744b591f905d935f81ef7d2ce970b09e1715a5e2131156c141afa874a3c6481e188a2f99d8abe160a9667ea1c73546c73bd5b83fcf1de91fb6a0846075b5707f4e881f2e3a107fd467e67c352ab4ed4e90ac7e6ebb777e781eecc985b040ede8b91b1de41485bf6c7b4b8a8ee886ce874253e6e6bb6b6dcb6645571e7753ef37571b235d91cbb2131d4c9314bb6884e6ac71d36fc64f413b7e8142debd401c23442869bfe523c311605d0f22b67c106adfd4c2b43312d89a842a8750538c5c81a6b74f9acb19943268943d25203e78e82249a33e448ac9b19d57eadacc566a8114a222c8aca0e31b432f324c5f933b6acecf99196169bcefa9b5d0841249ef17dc18c890a9ba9cd6d3bf29395a5694372c34397e86e67536ab54a3a687a1af6aab7eeb5b4897402a5d5b4ca8a2d1c8bfee114583e0aba292e854487edfe8da9175ccdda66a2db9b979146822ce38cacb321e5521b2e8a5aa4cde2f3acd10bc49cea0e147bea1e93ea759497c822357a52a9db7c68d6377c25097ed2c99b05f6e5f4f9e25d9975487e18f136a9b5b16aee1be837531eb466a8a428032dbd0914a263e60f0be9d87a6338b17b7cf1e75b7cee13ce8d473616d9fca8889a920bcc04723c0efb24ea4d6caad9da0b4196691e39380c616cb3aa6a4b3365dbce4241316d511b9329e97e5523b94163dec902f8618e78dd4283a7fc562c5904ddb8c54bf8615db3495c76fc16b6eef5ef02dd50f1b6ad4358d5aebd82f8234191e72c19578a3b21c7a29c6ce88bc3b7fda177fdf6a5a1be9a6efd0c680eed0876f9824d84bc7ddb6d9aa937175b7d95eb7684431b35021604eda35b8d7ee4e55966334ca32188f1ab3297437c95d7f87aeb4a970eeb3ba439de0ec83d642c27396e74cb9e9ccbdabde40d4b68e5a44431ddf9d12996647454d3ab2326d8396ed71d3ad69a6791c93abd95040428675486c214cee707c43aea7ded21c706f18ca52b63be137487cd328b51a5b4278949782d195e354c999edb67a102dd219e02bb82a1ce05b89ba7445beb879455c1fb134a59b7a75436e3aa66f50887140a43053a9209839c3137090bddabf20e27f459721a81b56253fe57d8074d7b12817eeba2095e5d49964746545427636aaa5b6bc5cc3196bebf0d17a6bb83384b83046c9ae3aa4568727a5b55222dcedb09ab11464bb705eb250c92d0fe59ab01cd188bb123c198a4caf4e90ba328472b5447728e9d877aa2f47c0283c62c9494259143e7e16b1bbaee952772ac8dac81b60e1133f67a758977671c4c94915138b12421819dcc5b8d41e36e7d718bee469aee0921c96dba5145b70c68d76c22871ed297bd9df3abce762b3cd6b80b8bd36a856434540d14284511821b0cb3231c84c95b033b97b292a35e77ea7a742ce5e8a188cbbd3c04f33c959cc9b7ce672b18329d54b8eef5eb4decd6a941e3fdb99417664233d9c3fefe61a9a69ea13297c26e8b0a5e61d68cbdbbc66e2e4488334a8d048d67b78d5687c76c26d7ad4d291cb913db99f978b815ae36a4d3ade73d3bda4b13f2c9598911a61ef7d45d0161f7044c116c45c802d4ed36471c1c84c857beeb6908a5d308da8'
    local message = util.hex2bin(c2)
    console.log('sendC2', #message)
    client:write(message)
end

local function sendConnect()
    -- 03 000000 0000f7 14 00000000 02 0007 636f6e6e656374 00 3ff0000000000000 03 0003 617070 02 0004 6c697665
    local connect = '030000000000f71400000000020007636f6e6e656374003ff00000000000000300036170700200046c6976650008666c61736856657202000e57494e2031352c302c302c323339000673776655726c0200000005746355726c02001c72746d703a2f2f696f742e626561636f6e6963652e636e2f6c6976650004667061640100000c6361706162696c697469'--c3657300406de00000000000000b617564696f436f646563730040abee0000000000000b766964656f436f6465637300406f800000000000000d766964656f46756e6374696f6e003ff000000000000000077061676555726c020000000e6f626a656374456e636f64696e67000000000000000000000009
    local message = util.hex2bin(connect)
    console.log('connect', #message)
    client:write(message)

    -- c3 fmt = 3
    local connect = 'c3657300406de00000000000000b617564696f436f646563730040abee0000000000000b766964656f436f6465637300406f800000000000000d766964656f46756e6374696f6e003ff000000000000000077061676555726c020000000e6f626a656374456e636f64696e67000000000000000000000009'
    local message = util.hex2bin(connect)
    console.log('connect', #message)
    client:write(message)

    client.connected = true
end

local function sendSetWindowAckSize()
    -- ACK size
    local connect = '02000000 00000405 00000000 002625a0'
    local message = util.hex2bin(connect)

    local header = rtmp.encodeChunkHeader(4)
    local body = string.pack('>I4', 2500000)
    local message = header .. body

    console.log('set ack size', #message)
    console.printBuffer(message)
    client:write(message)
end

local function sendCreateStream()
    local list = { 'createStream', 2, amf0.null }
    local body = amf0.encodeArray(list)
    local header = rtmp.encodeChunkHeader(#body)

    local message = header .. body

    console.log('createStream', #message)
    client:write(message)
end

local function sendPlay()
    --local play = '050000000000361401000000020004706c6179000000000000000000050200226c69766573747265616d3f2676686f73743d696f742e626561636f6e6963652e636e'
    --local message = util.hex2bin(play)
    local list = { 'play', 0, amf0.null, 'test' }
    local body = amf0.encodeArray(list)
    local header = rtmp.encodeChunkHeader(#body)

    local message = header .. body

    console.log('sendPlay', #message)
    client:write(message)
end

local function sendNextCommand()
    local function onWrite(err)
        --console.log("client:write", err)
    end

    if (state == 0) then
        sendC2()
        state = 1

        setTimeout(100, function() 
            sendNextCommand()
        end)

    elseif (state == 1) then
        sendConnect()
        state = 2

        setTimeout(100, function() 
            sendNextCommand()
        end)

    elseif (state == 2) then
        sendSetWindowAckSize()
        state = 3

    elseif (state == 3) then
        sendCreateStream()
        state = 4
        
    elseif (state == 4) then
        sendPlay()
        state = 5
    end
end

local function onConnect()
    console.log('onConnect')

    local onData, onWrite
    local lastData
    local chunkSize = 60000

    function onData(data)
        if (not client.connected) then
            sendNextCommand()
            return
        end

        local chunkData = nil
        if (lastData) then
            chunkData = lastData .. data
        else
            chunkData = data
        end

        console.log('client:on("data")', #chunkData)

        local index = 1;
        while (true) do
            if (index > #chunkData) then
                break
            end

            local header, body, raw = rtmp.parseChunk(chunkData, index)
            if (header == nil) then
                break
            end

            if (header.messageType == 0x12) then
                console.log('response', header.messageLength, #raw)

                if (client.stream and raw) then
                    local tagSize = #raw
                    local lastTagSize = client.lastTagSize or 0

                    local header = rtmp.flv.encodeTagHeader(0x12, tagSize, lastTagSize)
                    client.stream:write(header)

                    client.stream:write(raw)
                    client.lastTagSize = tagSize
                end

            elseif (header.messageType == 0x09) then
                console.log('response', header.messageLength, #raw)

                if (client.stream and raw) then
                    local tagSize = #raw
                    local lastTagSize = client.lastTagSize or 0

                    local header = rtmp.flv.encodeTagHeader(0x09, tagSize, lastTagSize)
                    client.stream:write(header)

                    client.stream:write(raw)
                    client.lastTagSize = tagSize
                end
            end

            index = index + header.headerSize + header.messageLength
        end

        lastData = nil
        if (index <= #chunkData) then
            if (index > 1) then
                lastData = chunkData:sub(index, #chunkData)
            else 
                lastData = chunkData
            end
        end

        if (lastData) then
            console.log('client:on("lastData")', #lastData, index, #chunkData)
        else
            console.log('client:on("lastData")', 'nil', index, #chunkData)
        end

        sendNextCommand()
    end

    function onWrite(err)
        console.log("client:write", err)
    end

    client:on("data", onData)
    
    sendC0C1()

    local filePath = '/tmp/test.flv'
    client.stream = fs.createWriteStream(filePath)

    local fileHeader = rtmp.flv.encodeFileHeader()
    client.stream:write(fileHeader)

    setTimeout(1000 * 10, function() 
        if (client.stream) then
            client.stream:finish()
            client.stream = nil
        end
    end)
end

local PORT = 1935;
local HOST = 'iot.wotcloud.cn'

client = net.Socket:new()
client:connect(PORT, HOST, onConnect)

client:on("error", function(error)
    console.log("client error", error)
end)

