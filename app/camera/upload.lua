
-------------------------------------------------------------------------------
-- upload

local UPLOAD_MAX_SIZE = 1024 * 1024 * 4
local await = utils.await


local function _takeAndSavePicture(filename)
    local mainCamera = exports.cameras['1']
    if (not mainCamera) then
        print("_takeAndSavePicture: Camera need open")
        return -1
    end 

    local sample = utils.await(mainCamera.takePicture, mainCamera)
    if (not sample) or (not sample.sampleData) then
        print("_takeAndSavePicture: bad sample")
        return -1
    end

    local data = sample.sampleData

    filename = filename or '/tmp/snapshot.jpg'
    print("Saved: " .. filename .. '(size:' .. #data .. ')')

    local err = utils.await(fs.writeFile, filename, data)
    if (err) then 
        return err
    end

    return 1
end


local function _takeAndPushVideo(name)
    utils.async(function()
        local mainCamera = exports.cameras[name]
        if (not mainCamera) then
            return -1
        end

        local sample = utils.await(mainCamera.takePicture, mainCamera)
        if (not sample) or (not sample.sampleData) then
            return -1
        end

        local data = sample.sampleData

        local hlsSegmenter = exports.hlsSegmenter or {}
        local filename = hlsSegmenter.lastSegmenter
        if (filename) then
            mqttPublishVideo(filename, 'video/ts', data, 'image/jpeg')
        end

        print('lastSegmenter', filename)
    end)

    return 1
end

local function uploadStream(filename, filedata)
    if (not filedata) then
        print("uploadStream: invalid stream data")
        return
    end

    local filesize = #filedata
    if (filesize <= 0) or (filesize > UPLOAD_MAX_SIZE) then
        print('uploadStream: not support file size: ', filesize)
        return
    end

    print('filesize', filesize, filename)

    -- upload file
    local file      = { name = filename, data = filedata }
    local files     = { file = file }
    local options   = { files = files }
    local url       = UPLOAD_URL
    local err, response, body = await(request.post, url, options)
    if (err) or (not body) then
        print('uploadStream', err)
        return
    end

    -- result
    local ret = json.parse(body) or {}
    if (ret.key) then
        ret.url = url .. ret.key
    end
    return ret
end

local function uploadFile(filename)
    -- check file size
    local err, statInfo = await(fs.stat, filename)
    if (err) or (not statInfo) then
        print('uploadFile', err)
        return
    end

    local filesize = statInfo.size
    if (filesize <= 0) or (filesize > UPLOAD_MAX_SIZE) then
        print('uploadFile: not support file size: ', filesize)
        return
    end

    -- read file data
    local err, filedata = await(fs.readFile, filename)
    if (err) or (not filedata) then
        print('uploadFile', err)
        return
    end

    return uploadStream(filename, filedata)
end

-------------------------------------------------------------------------------
-- MQTT publish

local SDCP_DEVICE_ID 	= 'sdcp.device_id'
local SDCP_DEVICE_KEY 	= 'sdcp.device_key'
local UPLOAD_URL        = "http://file.sae-sz.com/"

local function mqttPublishData(reported)
    local deviceKey = get(SDCP_DEVICE_KEY) or ''
    local deviceId  = get(SDCP_DEVICE_ID)  or ''
    
    -- message
    local key       = tostring(timestamp)
    local hash      = utils.bin2hex(utils.md5(deviceKey .. key))
    local message   = {
        device_id   = deviceId,
        device_key  = deviceKey,
        key         = key,
        hash        = hash,
        state       = {},
        version     = 10
    }

    -- message data
    local seq = 1
    local timestamp = os.time()
    local data = {
        reported    = reported,
        seq         = seq,
        timestamp   = timestamp
    }
    table.insert(message.state, data)
    --console.log(TAG, 'message', message)

    -- publish
    local dataTopic = '/device/data'
    local content = json.stringify(message)
    rpc.publish(dataTopic, content, 1, function(err, result)
        if (err) then
            print('MQTT message sent failed:')
            console.log(TAG, err)

        else
            print('MQTT message sent complete:')
            console.log(TAG, result)
        end
    end)
end

local function mqttPublishImage(filedata, mimetype)
    if (not filedata) then
        print("mqttPublishImage: invalid image data")
        return
    end

    utils.async(function()
        local ret = uploadStream('snapshot.jpg', filedata)
        if (not ret) or (not ret.key) then
            return
        end

        local reported = {
            url  = ret.url,
            name = ret.name,
            type = (mimetype or ret.type)
        }
        mqttPublishData(reported)
    end)
end

local function mqttPublishVideo(filename, videoType, imageData, imageType)
    if (not filename) then
        print("mqttPublishVideo: invalid video file")
        return
    end

    utils.async(function()
        -- upload video file
        local ret = uploadFile(filename, videoType)
        if (not ret) or (not ret.url) then
            return
        end

        local reported = {
            url  = ret.url,
            name = ret.name,
            type = (mimetype or ret.type)
        }

        -- upload thumbnail
        if (imageData) then
            local ret = uploadStream('snapshot.jpg', filedata)
            if (ret and ret.url) then
                reported.thumbnail = ret.url
            end
        end

        mqttPublishData(reported)
    end)
end

local function _takeAndPushPicture(name)
    utils.async(function()
        local mainCamera = exports.cameras[name]
        if (not mainCamera) then
            return -1
        end

        local sample = utils.await(mainCamera.takePicture, mainCamera)
        if (not sample) or (not sample.sampleData) then
            return -1
        end

        local data = sample.sampleData

        if (data) then
            mqttPublishImage(data, 'image/jpeg')
        end

    end)
    return 1
end


-- 测试图片上传功能 
function exports.upload(filename, mimetype)
    if (not filename) then
        return
    end

    utils.async(function()
        -- upload to file server
        local ret = uploadFile(filename, mimetype)
        if (not ret.key) then
            return
        end

        -- publish to MQTT server
        local data = {}
        data.url  = ret.url
        data.name = ret.name
        data.type = ret.type
        mqttPublishData(data)
    end)
end
