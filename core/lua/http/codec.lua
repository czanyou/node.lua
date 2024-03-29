--[[

Copyright 2014-2015 The Luvit Authors. All Rights Reserved.
Copyright 2016-2020 The Node.lua Authors. All Rights Reserved.

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

local meta = { }

meta.description = "A simple pair of functions for converting between hex and raw strings."

local exports = { meta = meta }

local sub    = string.sub
local gsub   = string.gsub
local lower  = string.lower
local find   = string.find
local format = string.format
local match  = string.match
local concat = table.concat

-------------------------------------------------------------------------------
-- STATUS_CODES

local STATUS_CODES = {
    [100] = 'Continue',
    [101] = 'Switching Protocols',
    [102] = 'Processing',
    -- RFC 2518, obsoleted by RFC 4918
    [200] = 'OK',
    [201] = 'Created',
    [202] = 'Accepted',
    [203] = 'Non-Authoritative Information',
    [204] = 'No Content',
    [205] = 'Reset Content',
    [206] = 'Partial Content',
    [207] = 'Multi-Status',
    -- RFC 4918
    [300] = 'Multiple Choices',
    [301] = 'Moved Permanently',
    [302] = 'Moved Temporarily',
    [303] = 'See Other',
    [304] = 'Not Modified',
    [305] = 'Use Proxy',
    [307] = 'Temporary Redirect',
    [400] = 'Bad Request',
    [401] = 'Unauthorized',
    [402] = 'Payment Required',
    [403] = 'Forbidden',
    [404] = 'Not Found',
    [405] = 'Method Not Allowed',
    [406] = 'Not Acceptable',
    [407] = 'Proxy Authentication Required',
    [408] = 'Request Time-out',
    [409] = 'Conflict',
    [410] = 'Gone',
    [411] = 'Length Required',
    [412] = 'Precondition Failed',
    [413] = 'Request Entity Too Large',
    [414] = 'Request-URI Too Large',
    [415] = 'Unsupported Media Type',
    [416] = 'Requested Range Not Satisfiable',
    [417] = 'Expectation Failed',
    [418] = "I'm a teapot",
    -- RFC 2324
    [422] = 'Unprocessable Entity',
    -- RFC 4918
    [423] = 'Locked',
    -- RFC 4918
    [424] = 'Failed Dependency',
    -- RFC 4918
    [425] = 'Unordered Collection',
    -- RFC 4918
    [426] = 'Upgrade Required',
    -- RFC 2817
    [500] = 'Internal Server Error',
    [501] = 'Not Implemented',
    [502] = 'Bad Gateway',
    [503] = 'Service Unavailable',
    [504] = 'Gateway Time-out',
    [505] = 'HTTP Version not supported',
    [506] = 'Variant Also Negotiates',
    -- RFC 2295
    [507] = 'Insufficient Storage',
    -- RFC 4918
    [509] = 'Bandwidth Limit Exceeded',
    [510] = 'Not Extended'-- RFC 2774
}

exports.STATUS_CODES = STATUS_CODES

-------------------------------------------------------------------------------
-- encoder

function exports.encoder()

    local httpEncodeMode
    local encodeHttpHeader, encodeRawContent, encodeChunkedContent

    function encodeHttpHeader(item)
        if not item or item == "" then
            return item

        elseif not(type(item) == "table") then
            error("expected a table but got a " .. type(item) .. " when encoding data")
        end

        local head, chunkedEncoding

        --console.log('item', item)

        -- start line
        local version = item.version or 1.1
        if item.method then
            local path = item.path
            assert(path and #path > 0, "expected non-empty path")
            head = { item.method .. ' ' .. item.path .. ' HTTP/' .. version .. '\r\n' }
        else
            local reason = item.reason or STATUS_CODES[item.code]
            head = { 'HTTP/' .. version .. ' ' .. item.code .. ' ' .. reason .. '\r\n' }
        end

        --if (item['Transfer-Encoding'] == "chunked") then
        --    item['Content-Length'] = nil
        --end

        -- headers
        for i = 1, #item do
            local key, value = table.unpack(item[i])
            local lowerKey = lower(key)
            if lowerKey == "transfer-encoding" then
                chunkedEncoding = lower(value) == "chunked"
            end

            value = gsub(tostring(value), "[\r\n]+", " ")
            head[#head + 1] = key .. ': ' .. tostring(value) .. '\r\n'
        end

        head[#head + 1] = '\r\n'

        --console.log('chunkedEncoding', chunkedEncoding)

        -- cotent
        httpEncodeMode = chunkedEncoding and encodeChunkedContent or encodeRawContent
        return concat(head)
    end

    function encodeRawContent(item)
        if type(item) ~= "string" then
            httpEncodeMode = encodeHttpHeader
            return encodeHttpHeader(item)
        end

        return item
    end

    function encodeChunkedContent(item)
        if type(item) ~= "string" then
            httpEncodeMode = encodeHttpHeader
            local extra = encodeHttpHeader(item)
            if extra then
                return "0\r\n\r\n" .. extra
            else
                return "0\r\n\r\n"
            end
        end

        if #item == 0 then
            httpEncodeMode = encodeHttpHeader
        end

        return format("%x", #item) .. "\r\n" .. item .. "\r\n"
    end

    httpEncodeMode = encodeHttpHeader
    return function(item)
        return httpEncodeMode(item)
    end
end

-------------------------------------------------------------------------------
-- decoder

function exports.decoder()

    -- This decoder is somewhat stateful with 5 different parsing states.
    local decodeHeaders, decodeEmpty, decodeRaw, decodeChunked, decodeCounted

    local mode      -- state variable that points to various decoders
    local bytesLeft -- For counted decoder

    -- This state is for decoding the status line and headers.
    function decodeHeaders(chunk)
        if not chunk then return end

        local _, length = find(chunk, "\r?\n\r?\n", 1)
        -- First make sure we have all the head before continuing
        if not length then
            if #chunk < 8 * 1024 then return end
            -- But protect against evil clients by refusing heads over 8K long.
            error("entity too large")
        end

        -- Parse the status/request line
        local head = { }
        local _, offset
        local version

        -- `HTTP/1.1 ### xxx\r\n`
        _, offset, version, head.code, head.reason =
            chunk:find("^HTTP/(%d%.%d) (%d+) ([^\r\n]+)\r?\n")

        if (not offset) then
            -- `HTTP/1.1 ###\r\n`
            _, offset, version, head.code, head.reason =
                chunk:find("^HTTP/(%d%.%d) (%d+)\r?\n")
        end

        if offset then
            head.code = tonumber(head.code)

        else
            -- `XXX xxx HTTP/1.1\r\n`
            _, offset, head.method, head.path, version =
                chunk:find("^([%u-]+)[ ]+([^ ]+) HTTP/(%d%.%d)\r?\n")
            if not offset then
                console.log(chunk)
                error("expected HTTP data")
            end
        end

        version = tonumber(version)
        head.version    = version
        head.keepAlive  = version > 1.0

        -- We need to inspect some headers to know how to parse the body.
        local contentLength
        local chunkedEncoding

        -- Parse the header lines
        while true do
            local key, value
            _, offset, key, value = chunk:find("^([^:\r\n]+): *([^\r\n]+)\r?\n", offset + 1)
            if not offset then break end
            local lowerKey = lower(key)

            -- Inspect a few headers and remember the values
            if lowerKey == "content-length" then
                contentLength = tonumber(value)

            elseif lowerKey == "transfer-encoding" then
                chunkedEncoding = lower(value) == "chunked"

            elseif lowerKey == "connection" then
                head.keepAlive = lower(value) == "keep-alive"
            end

            head[#head + 1] = { key, value }
        end

        --console.log('decodeHeaders', contentLength, chunkedEncoding, head.keepAlive)

        if head.keepAlive and (not(chunkedEncoding or(contentLength and contentLength > 0))) then
            mode = decodeEmpty

        elseif (head.method == "GET") or (head.method == "HEAD") then
            mode = decodeEmpty

        elseif chunkedEncoding then
            mode = decodeChunked

        elseif contentLength then
            bytesLeft = contentLength
            mode = decodeCounted

        elseif not head.keepAlive then
            mode = decodeRaw
        end

        return head, chunk:sub(length + 1)
    end

    -- This is used for inserting a single empty string into the output string for known empty bodies
    function decodeEmpty(chunk)
        mode = decodeHeaders
        return "", chunk or ""
    end

    function decodeRaw(chunk)
        if not chunk then
            return "", ""
        end

        if #chunk == 0 then
            return
        end

        return chunk, ""
    end

    function decodeChunked(chunk)
        local len, term
        len, term = match(chunk, "^(%x+)(..)")
        if not len then return end

        assert(term == "\r\n")
        local length = tonumber(len, 16)
        if #chunk < length + 4 + #len then
            return
        end

        if length == 0 then
            mode = decodeHeaders
        end

        chunk = sub(chunk, #len + 3)
        assert(sub(chunk, length + 1, length + 2) == "\r\n")
        return sub(chunk, 1, length), sub(chunk, length + 3)
    end

    function decodeCounted(chunk)
        if bytesLeft == 0 then
            mode = decodeEmpty
            return mode(chunk)
        end

        local length = #chunk

        -- Make sure we have at least one byte to process
        if length == 0 then
            return
        end

        if length >= bytesLeft then
            mode = decodeEmpty
        end

        -- If the entire chunk fits, pass it all through
        if length <= bytesLeft then
            bytesLeft = bytesLeft - length
            return chunk, ""
        end

        return chunk:sub(1, bytesLeft), chunk:sub(bytesLeft + 1)
    end

    -- Switch between states by changing which decoder mode points to
    mode = decodeHeaders

    return function(chunk)
        return mode(chunk)
    end

end

function exports.createDecoder(options, callback)
    local decoder = {}
    decoder.buffer = ""

    local decode = exports.decoder()

    decoder.decode = function(chunk)

        decoder.buffer = decoder.buffer .. chunk
        --console.log('buffer', decoder.buffer)

        while true do
            local R, event, extra = pcall(decode, decoder.buffer)
            --console.log('decode', R, event, extra)

            if not R then
                --socket:emit('error', event)
                if (callback) then callback(nil, event) end
                break
            end

            -- nil extra means the decoder needs more data, we're done here.
            if not extra then
                break
            end

            -- Store the leftover data.
            decoder.buffer = extra

            if (event and callback) then
                if (callback(event)) then
                    break
                end
            end
        end -- end while
    end

    return decoder
end

return exports
