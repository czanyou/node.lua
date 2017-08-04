--[[

Copyright 2015 The Luvit Authors. All Rights Reserved.
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

--[[

This module has utilities for URL resolution and parsing. Call require('url') 
to use it.

URL Parsing
=========

Parsed URL objects have some or all of the following fields, depending on 
whether or not they exist in the URL string. Any parts that are not in the URL 
string will not be in the parsed object. Examples are shown for the URL

'http://user:pass@host.com:8080/p/a/t/h?query=string#hash'

href: The full URL that was originally parsed. Both the protocol and host are lowercased.
    Example: 'http://user:pass@host.com:8080/p/a/t/h?query=string#hash'

protocol: The request protocol, lowercased.
    Example: 'http:'

slashes: The protocol requires slashes after the colon.
    Example: true or false

host: The full lowercased host portion of the URL, including port information.
    Example: 'host.com:8080'

auth: The authentication information portion of a URL.
    Example: 'user:pass'

hostname: Just the lowercased hostname portion of the host.
    Example: 'host.com'

port: The port number portion of the host.
    Example: '8080'

pathname: The path section of the URL, that comes after the host and before the 
query, including the initial slash if present. No decoding is performed.
    Example: '/p/a/t/h'

search: The 'query string' portion of the URL, including the leading question mark.
    Example: '?query=string'

path: Concatenation of pathname and search. No decoding is performed.
    Example: '/p/a/t/h?query=string'

query: Either the 'params' portion of the query string, or a querystring-parsed object.
    Example: 'query=string' or {'query':'string'}

hash: The 'fragment' portion of the URL including the pound-sign.
    Example: '#hash'

Escaped Characters
=========

Spaces (' ') and the following characters will be automatically escaped in the 
properties of URL objects:

    < > " ` \r \n \t { } | \ ^ '

--]]
local meta = { }
meta.name        = "lnode/url"
meta.version     = "1.0.4-2"
meta.license     = "Apache 2"
meta.description = "Node-style url codec for lnode"
meta.tags        = { "lnode", "url", "codec" }

local exports = { meta = meta }

local querystring = require('querystring')

--[[
Take a URL string, and return an object.

Pass true as the second argument to also parse the query string using the 
querystring module. If true then the query property will always be assigned an 
object, and the search property will always be a (possibly empty) string. If 
false then the query property will not be parsed or decoded. Defaults to false.

--]]
function exports.parse(url, parseQueryString)
    if (not url) or (url == '') then
        return nil
    end

    local href = url
    local chunk, protocol = url:match("^(([a-z0-9+]+)://)")
    url = url:sub((chunk and #chunk or 0) + 1)

    local auth
    chunk, auth = url:match('(([0-9a-zA-Z]+:?[0-9a-zA-Z]+)@)')
    url = url:sub((chunk and #chunk or 0) + 1)

    local host
    local hostname
    local port
    if protocol then
        host = url:match("^([%a%.%d-]+:?%d*)")
        if host then
            hostname = host:match("^([^:/]+)")
            port = host:match(":(%d+)$")
        end
        url = url:sub((host and #host or 0) + 1)
    end

    host = hostname
    -- Just to be compatible with our code base. Discuss this.

    local path
    local pathname
    local search
    local query
    local hash
    hash = url:match("(#.*)$")
    url = url:sub(1,(#url -(hash and #hash or 0)))

    if url ~= '' then
        path = url
        local temp
        temp = url:match("^[^?]*")
        if temp ~= '' then
            pathname = temp
        end
        temp = url:sub((pathname and #pathname or 0) + 1)
        if temp ~= '' then
            search = temp
        end
        if search then
            temp = search:sub(2)
            if temp ~= '' then
                query = temp
            end
        end
    end

    if parseQueryString then
        query = querystring.parse(query)
    end

    return {
        href     = href,
        protocol = protocol,
        host     = host,
        hostname = hostname,
        port     = port,
        path     = path or '/',
        pathname = pathname or '/',
        search   = search,
        query    = query,
        auth     = auth,
        hash     = hash
    }

end


--[[
Take a parsed URL object, and return a formatted URL string.

Here's how the formatting process works:

- href will be ignored.
- path will be ignored.
- protocol is treated the same with or without the trailing : (colon).
- - The protocols http, https, ftp, gopher, file will be postfixed with :// (colon-slash-slash).
- - All other protocols mailto, xmpp, aim, sftp, foo, etc will be postfixed with : (colon).

- slashes set to true if the protocol requires :// (colon-slash-slash)
- - Only needs to be set for protocols not previously listed as requiring slashes, 
    such as mongodb://localhost:8000/.

- auth will be used if present.
- hostname will only be used if host is absent.
- port will only be used if host is absent.
- host will be used in place of hostname and port.
- pathname is treated the same with or without the leading / (slash).
- query (object; see querystring) will only be used if search is absent.
- search will be used in place of query.
- - It is treated the same with or without the leading ? (question mark).

- hash is treated the same with or without the leading # (pound sign, anchor).

]]
function exports.format(urlObj)
    if (not urlObj) then
        return nil
    end

    local utils = require("utils")

    local sb = utils.StringBuffer:new()
    local host = urlObj.hostname or urlObj.host

    if (host) then
        sb:append(urlObj.protocol)
        sb:append('://')

        if (urlObj.auth) then
            sb:append(urlObj.auth)
            sb:append('@')
        end

        sb:append(host)

        if (urlObj.port) then
            sb:append(':'):append(urlObj.port)
        end
    end

    sb:append(urlObj.pathname or '/')

    if (urlObj.query) then
        sb:append('?'):append(urlObj.query)
    end   

    if (urlObj.hash) then
        sb:append(''):append(urlObj.hash)
    end

    return sb:toString()
end

--[[
Take a base URL, and a href URL, and resolve them as a browser would for an anchor tag. Examples:

```
    url.resolve('/one/two/three', 'four')         // '/one/two/four'
    url.resolve('http://example.com/', '/one')    // 'http://example.com/one'
    url.resolve('http://example.com/one', '/two') // 'http://example.com/two'
```

]]
function exports.resolve(from, to)
    local path = require("path").posix

    local urlObject = exports.parse(from)

    local pathname = urlObject.pathname or "/"
    if (pathname ~= "/") then
        pathname = path:dirname(pathname) or "/"
    end

    pathname = path:join(pathname, to)
    urlObject.pathname = pathname

    return exports.format(urlObject)
end

return exports
