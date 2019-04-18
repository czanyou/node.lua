local client = require('rtsp/client')

local exports = {}

exports.client = client

-------------------------------------------------------------------------------
-- exports

--[[
打开指定的 RTSP URL 地址，并返回相关的 RTSP 客户端对象
@param url RTSP URL 地址, 比如 'rtsp://test.com:554/live.mp4'
]]
function exports.openURL(url)
	local rtspClient = client.RtspClient:new()
	rtspClient:open(url)
	return rtspClient
end

return exports
