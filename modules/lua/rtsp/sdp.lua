--[[

Copyright 2016 The Node.lua Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]
local core = require('core')

local meta 		= { }
local exports 	= { meta = meta }

--[[
这个模块主要用于会话描述协议（SDP）字符串解码，关于 SDP 的详细信息请参考：
http://node.sae-sz.com/?p=docs&f=vision_media_sdp.md
--]]

-------------------------------------------------------------------------------
-- SdpMedia

-- SdpMedia 代表 SDP 中的一个 media 分节，用来描述一个视频或音频流的具体信息.

local SdpMedia = core.Object:extend()
exports.SdpMedia = SdpMedia

function SdpMedia:getAttribute(key)
    if (not self.attributes) then
        return
    end

    return self.attributes[key]
end

-- 帧率
function SdpMedia:getFramerate(payload)
    local attribute = self:getAttribute('framerate', payload)
    return tonumber(attribute)
end

-- 图像尺寸，如: framesize:97 240-160
function SdpMedia:getFramesize(payload)
    local attribute = self:getAttribute('framesize', payload)
    if (not attribute) then
        return
    end
    
    local framesize = {}
    local key, value

    -- payload
    _, offset, value = attribute:find("^([^ ]+) ?", offset)
    framesize.payload = tonumber(value)

    -- parameters
    local value = attribute:sub(offset + 1)
    if (value) then
        local tokens = value:split("-")
        framesize.width  = tonumber(tokens[1])
        framesize.height = tonumber(tokens[2])
    end

    return framesize
end

-- 编解码基本信息, 如：rtpmap:97 H264/90000，表示编码类型为 H.264, 时间戳频率为 90000
function SdpMedia:getRtpmap(payload)
    local attribute = self:getAttribute('rtpmap', payload)
    if (not attribute) then
        return
    end

    local rtpmap = {}
    local offset = 1

    local key, value

    -- payload
    _, offset, value = attribute:find("^([^ ]+) ?", offset)
    rtpmap.payload = tonumber(value)

    -- parameters
    local value = attribute:sub(offset + 1)
    if (value) then
        local tokens = value:split("/")
        rtpmap.codec     = tokens[1]
        rtpmap.frequency = tonumber(tokens[2])
    end

    return rtpmap
end

-- 编解码详细信息, 如 H.264 的 profile 级别，SPS，PPS 数据集等
function SdpMedia:getFmtp(payload)
    local attribute = self:getAttribute('fmtp', payload)
    if (not attribute) then
        return
    end

    local fmtp = {}

    local offset = 1
    local key, value

    -- payload
    _, offset, value = attribute:find("^([^ ]+) ?", offset)
    fmtp.payload = tonumber(value)

    -- parameters
    while (value) do
        _, offset, value = attribute:find("^([^;]+) ?", offset + 2)
        if (value) then
            _, _, k, v = value:find("^([^=]+)=([^;]+) ?")
            if (k) then
                fmtp[k] = v
            end
        end
    end

    return fmtp
end

-------------------------------------------------------------------------------
-- SdpSession

local SdpSession = core.Object:extend()
exports.SdpSession = SdpSession

function SdpSession:initialize()
    
end

-- 返回这个 SDP 会话包含的 media 的数量
function SdpSession:getMediaCount()
    if (not self.medias) then
        return 0
    end

    return #self.medias
end

-- 返回指定的类型的 media
-- @param type，如 'video', 'audio', 等等
function SdpSession:getMedia(type)
    if (not self.medias) then
        return nil
    end

    for key, media in pairs(self.medias) do
        if (media.type == type) then
            return media
        end
    end
end

-------------------------------------------------------------------------------
-- exports

-- 解析 "m=...", 如 "m=video 0 RTP/AVP 97"
-- 返回 media 对象，其属性定义如下：
-- - type 媒体类型，如 'video', 'audio'
-- - port 端口，默认为 0
-- - mode 传输模式，如 "RTP/AVP" 表示用 RTP 传输
-- - payload RTP 负载类型, 大于等于 96 表示自定义类型
local function decodeMedia(media, sdpLine)
    local offset = 0
    local index = 1
    while true do
        local value
        _, offset, value = sdpLine:find("^([^ ]+) ?", offset + 1)
        if not offset then break end
        -- p(index, offset, key, value)

        if (index == 1) then
            media.type = value

        elseif (index == 2) then
            media.port = tonumber(value)
        
        elseif (index == 3) then
            media.mode = value

        elseif (index == 4) then
            media.payload = tonumber(value)     
        end

        index = index + 1;
    end
end

-- 解析 "a=..."
local function decodeAttributes(sdp, sdpLine)
    local _, offset, name, data = sdpLine:find("^([^:]+):([^\r\n]+)", 1)

    if (name) then
        if (sdp.attributes == nil) then
            sdp.attributes = {}
        end

        sdp.attributes[name] = data
    end
end

-- 解析指定的 SDP 字符串
function exports.decode(sdpString)
    if (not sdpString) then
        return
    end

    local sdp = SdpSession:new()
    local media = nil
    local offset = 0

    sdp.medias = {}

    local fmt = "^([^:\r\n]+)=([^\r\n]+)\r?\n"

    while true do
        local key, value
        _, offset, key, value = sdpString:find(fmt, offset + 1)

        if not offset then break end

        if key == 'm' then
            media = SdpMedia:new()
            decodeMedia(media, value)
            table.insert(sdp.medias, media)

        elseif (media) then 
            -- console.log(offset, key, value)

            if key == 'a' then
                decodeAttributes(media, value)

            else
                media[key] = value
            end

        else 
            if key == 'a' then
                decodeAttributes(sdp, value)

            else
                sdp[key] = value
            end
        end
    end

    return sdp
end

return exports
