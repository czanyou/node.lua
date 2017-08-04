--[[

Copyright 2014-2015 The Luvit Authors. All Rights Reserved.
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

-- Derived from Yichun Zhang (agentzh)
-- https://github.com/openresty/lua-resty-dns/blob/master/lib/resty/dns/resolver.lua

local meta = {}
meta.name        = "lnode/dns"
meta.version     = "1.0.1"
meta.license     = "Apache 2"
meta.description = "Node-style dns module for lnode"
meta.tags        = { "lnode", "dns" }

local exports = { meta = meta }

local dgram = require('dgram')
local fs    = require('fs')
local net   = require('net')
local timer = require('timer')

local Error  = require('core').Error
local adapt  = require('utils').adapt
local crypto = require('tls/lcrypto')

local DEFAULT_SERVERS = {
    {
        ['host'] = '8.8.8.8',
        ['port'] = 53,
        ['tcp']  = false
    },
    {
        ['host'] = '8.8.4.4',
        ['port'] = 53,
        ['tcp']  = false
    },
}

local DEFAULT_TIMEOUT = 2000   -- 2 seconds

local SERVERS       = DEFAULT_SERVERS
local TIMEOUT       = DEFAULT_TIMEOUT

local DOT_CHAR      = 46

exports.TYPE_A      = 1
exports.TYPE_NS     = 2
exports.TYPE_CNAME  = 5
exports.TYPE_PTR    = 12
exports.TYPE_MX     = 15
exports.TYPE_TXT    = 16
exports.TYPE_AAAA   = 28
exports.TYPE_SRV    = 33

exports.CLASS_IN    = 1

local resolver_errstrs = {
    "format error",     -- 1
    "server failure",   -- 2
    "name error",       -- 3
    "not implemented",  -- 4
    "refused",          -- 5
}


local function _gen_id(self)
    local bytes = crypto.randomBytes(2)
    return ((bytes:byte(1) << 8) | (bytes:byte(2) & 0xff))
end


local function _encode_name(s)
    return string.char(#s) .. s
end

local function _decode_name(buf, pos)
    local labels = { }
    local nptrs = 0
    local p = pos
    while nptrs < 128 do
        local fst = buf:byte(p)

        if not fst then
            return nil, 'truncated';
        end

        -- print("fst at ", p, ": ", fst)

        if fst == 0 then
            if nptrs == 0 then
                pos = pos + 1
            end
            break
        end

        if (fst & 0xc0) ~= 0 then
            -- being a pointer
            if nptrs == 0 then
                pos = pos + 2
            end

            nptrs = nptrs + 1

            local snd = buf:byte(p + 1)
            if not snd then
                return nil, 'truncated'
            end

            p = ((fst & 0x3f) << 8) + snd + 1

            -- print("resolving ptr ", p, ": ", buf:byte(p))

        else
            -- being a label
            local label = buf:sub(p + 1, p + fst)
            table.insert(labels, label)

            -- print("resolved label ", label)

            p = p + fst + 1

            if nptrs == 0 then
                pos = p
            end
        end
    end

    return table.concat(labels, "."), pos
end

local function _build_request(qname, id, no_recurse, opts)
    local qtype

    if opts then
        qtype = opts.qtype
    end

    if not qtype then
        qtype = 1
        -- A record
    end

    local ident_hi = string.char(id >> 8)
    local ident_lo = string.char(id & 0xff)

    local flags
    if no_recurse then
        -- print("found no recurse")
        flags = "\0\0"
    else
        flags = "\1\0"
    end

    local nqs = "\0\1"
    local nan = "\0\0"
    local nns = "\0\0"
    local nar = "\0\0"
    local typ = "\0" .. string.char(qtype)
    local class = "\0\1"
    -- the Internet class

    if qname:byte(1) == DOT_CHAR then
        return nil, "bad name"
    end

    local name = qname:gsub("([^.]+)%.?", _encode_name) .. '\0'

    return {
        ident_hi, ident_lo, flags, nqs, nan, nns, nar,
        name, typ, class
    }
end

local function _parse_response(buf, id)
    local n = #buf
    if n < 12 then
        return nil, 'truncated';
    end

    -- header layout: ident flags nqs nan nns nar

    local ident_hi = buf:byte(1)
    local ident_lo = buf:byte(2)
    local ans_id   = (ident_hi << 8) + ident_lo

    -- print("id: ", id, ", ans id: ", ans_id)

    if ans_id ~= id then
        -- identifier mismatch and throw it away
        return nil, "id mismatch"
    end

    local flags_hi = buf:byte(3)
    local flags_lo = buf:byte(4)
    local flags    = (flags_hi << 8) + flags_lo

    -- print(format("flags: 0x%x", flags))

    if (flags & 0x8000) == 0 then
        return nil, string.format("bad QR flag in the DNS response")
    end

    if (flags & 0x200) ~= 0 then
        return nil, "truncated"
    end

    local code = (flags & 0x7f)

    -- print(format("code: %d", code))

    local nqs_hi = buf:byte(5)
    local nqs_lo = buf:byte(6)
    local nqs    = (nqs_hi << 8) + nqs_lo

    -- print("nqs: ", nqs)

    if nqs ~= 1 then
        return nil, string.format("bad number of questions in DNS response: %d", nqs)
    end

    local nan_hi = buf:byte(7)
    local nan_lo = buf:byte(8)
    local nan    = (nan_hi << 8) + nan_lo

    -- print("nan: ", nan)

    -- skip the question part

    local ans_qname, pos = _decode_name(buf, 13)
    if not ans_qname then
        return nil, pos
    end

    -- print("qname in reply: ", ans_qname)

    -- print("question: ", sub(buf, 13, pos))

    if pos + 3 + nan * 12 > n then
        -- print(format("%d > %d", pos + 3 + nan * 12, n))
        return nil, 'truncated';
    end

    -- question section layout: qname qtype(2) qclass(2)

    local type_hi, type_lo

    -- local type_hi = buf:byte(pos)
    -- local type_lo = buf:byte(pos + 1)
    -- local ans_type = lshift(type_hi, 8) + type_lo
    -- print("ans qtype: ", ans_type)

    local class_hi = buf:byte(pos + 2)
    local class_lo = buf:byte(pos + 3)
    local qclass   = (class_hi << 8) + class_lo

    -- print("ans qclass: ", qclass)

    if qclass ~= 1 then
        return nil, string.format("unknown query class %d in DNS response", qclass)
    end

    pos = pos + 4

    local answers = { }

    if code ~= 0 then
        answers = Error:new(
        code .. ': ' .. resolver_errstrs[code] or "unknown"
        )
    end

    for i = 1, nan do
        -- print(format("ans %d: qtype:%d qclass:%d", i, qtype, qclass))

        local ans = { }
        table.insert(answers, ans)

        local name
        name, pos = _decode_name(buf, pos)
        if not name then
            return nil, pos
        end

        ans.name = name

        -- print("name: ", name)

        type_hi = buf:byte(pos)
        type_lo = buf:byte(pos + 1)
        local typ = (type_hi << 8) + type_lo

        ans.type = typ

        -- print("type: ", typ)

        class_hi = buf:byte(pos + 2)
        class_lo = buf:byte(pos + 3)
        local class = (class_hi << 8) + class_lo

        ans.class = class

        -- print("class: ", class)

        local ttl_bytes = { buf:byte(pos + 4, pos + 7) }

        -- print("ttl bytes: ", concat(ttl_bytes, " "))

        local ttl = (ttl_bytes[1] << 24) + (ttl_bytes[2] << 16)
        + (ttl_bytes[3] << 8) + ttl_bytes[4]

        -- print("ttl: ", ttl)

        ans.ttl = ttl

        local len_hi = buf:byte(pos + 8)
        local len_lo = buf:byte(pos + 9)
        local len = (len_hi << 8) + len_lo

        -- print("record len: ", len)

        pos = pos + 10

        if typ == exports.TYPE_A then

            if len ~= 4 then
                return nil, "bad A record value length: " .. len
            end

            local addr_bytes = { buf:byte(pos, pos + 3) }
            local addr = table.concat(addr_bytes, ".")
            -- print("ipv4 address: ", addr)

            ans.address = addr

            pos = pos + 4

        elseif typ == exports.TYPE_CNAME then

            local cname, p = _decode_name(buf, pos)
            if not cname then
                return nil, pos
            end

            if p - pos ~= len then
                return nil, string.format("bad cname record length: %d ~= %d",
                p - pos, len)
            end

            pos = p

            -- print("cname: ", cname)

            ans.cname = cname

        elseif typ == exports.TYPE_AAAA then

            if len ~= 16 then
                return nil, "bad AAAA record value length: " .. len
            end

            local addr_bytes = { buf:byte(pos, pos + 15) }
            local flds = { }
            for idx = 1, 16, 2 do
                local a = addr_bytes[idx]
                local b = addr_bytes[idx + 1]
                if a == 0 then
                    table.insert(flds, string.format("%x", b))

                else
                    table.insert(flds, string.format("%x%02x", a, b))
                end
            end

            -- we do not compress the IPv6 addresses by default
            --  due to performance considerations

            ans.address = table.concat(flds, ":")

            pos = pos + 16

        elseif typ == exports.TYPE_MX then

            -- print("len = ", len)

            if len < 3 then
                return nil, "bad MX record value length: " .. len
            end

            local pref_hi = buf:byte(pos)
            local pref_lo = buf:byte(pos + 1)

            ans.preference = (pref_hi << 8) + pref_lo

            local host, p = _decode_name(buf, pos + 2)
            if not host then
                return nil, pos
            end

            if p - pos ~= len then
                return nil, string.format("bad cname record length: %d ~= %d",
                p - pos, len)
            end

            ans.exchange = host

            pos = p

        elseif typ == exports.TYPE_SRV then
            if len < 7 then
                return nil, "bad SRV record value length: " .. len
            end

            local prio_hi = buf:byte(pos)
            local prio_lo = buf:byte(pos + 1)
            ans.priority = (prio_hi << 8) + prio_lo

            local weight_hi = buf:byte(pos + 2)
            local weight_lo = buf:byte(pos + 3)
            ans.weight = (weight_hi << 8) + weight_lo

            local port_hi = buf:byte(pos + 4)
            local port_lo = buf:byte(pos + 5)
            ans.port = (port_hi << 8) + port_lo

            local recname, p = _decode_name(buf, pos + 6)
            if not recname then
                return nil, pos
            end

            if p - pos ~= len then
                return nil, string.format("bad srv record length: %d ~= %d", p - pos, len)
            end

            ans.target = recname

            pos = p

        elseif typ == exports.TYPE_NS then

            local recname, p = _decode_name(buf, pos)
            if not recname then
                return nil, pos
            end

            if p - pos ~= len then
                return nil, string.format("bad cname record length: %d ~= %d",
                p - pos, len)
            end

            pos = p

            -- print("name: ", recname)

            ans.nsdname = recname

        elseif typ == exports.TYPE_TXT then

            local slen = buf:byte(pos)
            if slen + 1 > len then
                -- truncate the over-run TXT record data
                slen = len
            end

            -- print("slen: ", len)

            local val = buf:sub(pos + 1, pos + slen)
            local last = pos + len
            pos = pos + slen + 1

            if pos < last then
                -- more strings to be processed
                -- this code path is usually cold, so we do not
                -- merge the following loop on this code path
                -- with the processing logic above.

                val = { val }
                local idx = 2
                repeat
                    local recslen = buf:byte(pos)
                    if pos + recslen + 1 > last then
                        -- truncate the over-run TXT record data
                        recslen = last - pos - 1
                    end

                    val[idx] = buf:sub(pos + 1, pos + recslen)
                    idx = idx + 1
                    pos = pos + recslen + 1

                until pos >= last
            end

            ans.txt = val

        elseif typ == exports.TYPE_PTR then

            local recname, p = _decode_name(buf, pos)
            if not recname then
                return nil, pos
            end

            if p - pos ~= len then
                return nil, string.format("bad cname record length: %d ~= %d",
                p - pos, len)
            end

            pos = p

            -- print("name: ", recname)

            ans.ptrdname = recname

        else
            -- for unknown types, just forward the raw value

            ans.rdata = buf:sub(pos, pos + len - 1)
            pos = pos + len
        end
    end

    return answers
end

local function _query(servers, name, dnsclass, qtype, callback)
    local tries, max_tries, server, tcp_iter, udp_iter, get_server_iter

    tries = 1
    max_tries = 5

    get_server_iter = function()
        local i = 1
        return function()
            i =(i % #servers) + 1
            return servers[i]
        end
    end

    server = get_server_iter()

    tcp_iter = function()
        local srv, id, req, len, len_hi, len_lo, sock
        local _onTimeout, _onConnect, _onData, _onError

        tries = tries + 1
        if tries > max_tries then
            return callback(Error:new('Maximum attempts reached'))
        end

        srv     = server()
        id      = _gen_id()
        req     = _build_request(name, id, false, { qtype = qtype })
        req     = table.concat(req, "")
        len     = #req
        len_hi  = string.char((len >> 8))
        len_lo  = string.char((len & 0xff))
        sock    = net.Socket:new()

        function _onError(err)
            sock:destroy()
            timer.setImmediate(tcp_iter)
        end

        function _onTimeout()
            sock:destroy()
            timer.setImmediate(tcp_iter)
        end

        function _onConnect(err)
            if err then
                sock:destroy()
                return timer.setImmediate(tcp_iter)
            end

            sock:on('data',  _onData)
            sock:on('error', _onError)
            sock:write(table.concat( { len_hi, len_lo, req }))
        end

        function _onData(msg)
            local len_hi, len_lo, len, answers

            len_hi = msg:byte(1)
            len_lo = msg:byte(2)
            len = (len_hi << 8) + len_lo

            assert(#msg - 2 == len)

            sock:destroy()

            answers = _parse_response(msg:sub(3), id)
            if not answers then
                timer.setImmediate(tcp_iter)
                
            else
                if answers.code then
                    callback(answers)
                else
                    callback(nil, answers)
                end
            end
        end

        sock:setTimeout(TIMEOUT, _onTimeout)
        sock:connect(srv.port, srv.host, _onConnect)
    end

    udp_iter = function()
        local srv, id, req, sock, _onTimeout, _onMessage, _onError

        tries = tries + 1
        if tries > max_tries then
            return callback(Error:new('Maximum attempts reached'))
        end

        srv     = server()
        id      = _gen_id()
        req     = _build_request(name, id, false, { qtype = qtype })
        sock    = dgram.createSocket()

        function _onError(err)
            sock:close()
            timer.setImmediate(udp_iter)
        end

        function _onTimeout()
            sock:close()
            timer.setImmediate(udp_iter)
        end

        function _onMessage(msg)
            sock:close()

            local answers, err = _parse_response(msg, id)
            if answers then
                if answers.code then
                    callback(answers)
                else
                    callback(nil, answers)
                end

            else
                if err == 'truncated' then
                    timer.setImmediate(tcp_iter)
                else
                    timer.setImmediate(udp_iter)
                end
            end
        end

        sock:send(table.concat(req), srv.port, srv.host)
        sock:recvStart()
        sock:setTimeout(TIMEOUT, _onTimeout)
        sock:on('message', _onMessage)
        sock:on('error',   _onError)
    end

    if server().tcp then
        tcp_iter()

    else
        udp_iter()
    end
end

local function query(servers, name, dnsclass, qtype, callback)
    return adapt(callback, _query, servers, name, dnsclass, qtype)
end

exports.query = query

function exports.resolve4(name, callback)
    return query(SERVERS, name, exports.CLASS_IN, exports.TYPE_A, callback)
end

function exports.resolve6(name, callback)
    return query(SERVERS, name, exports.CLASS_IN, exports.TYPE_AAAA, callback)
end

function exports.resolveSrv(name, callback)
    return query(SERVERS, name, exports.CLASS_IN, exports.TYPE_SRV, callback)
end

function exports.resolveMx(name, callback)
    return query(SERVERS, name, exports.CLASS_IN, exports.TYPE_MX, callback)
end

function exports.resolveNs(name, callback)
    return query(SERVERS, name, exports.CLASS_IN, exports.TYPE_NS, callback)
end

function exports.resolveCname(name, callback)
    return query(SERVERS, name, exports.CLASS_IN, exports.TYPE_CNAME, callback)
end

function exports.resolveTxt(name, callback)
    return query(SERVERS, name, exports.CLASS_IN, exports.TYPE_TXT, callback)
end

function exports.setServers(servers)
    SERVERS = servers
end

function exports.setTimeout(timeout)
    TIMEOUT = timeout
end

function exports.setDefaultTimeout()
    TIMEOUT = DEFAULT_TIMEOUT
end

function exports.setDefaultServers()
    SERVERS = DEFAULT_SERVERS
end

function exports.loadResolver(options)
    local servers = { }

    options = options or {
        file = '/etc/resolv.conf'
    }

    local data, err = fs.readFileSync(options.file)
    if err then return end

    local posa = 1

    local function _parse(line)
        if not(line:match('^#') or line:match('^;')) then
            local ip = line:match('^nameserver%s([a-fA-F0-9:\\.]+)')
            if ip then
                local server = { }
                server.host = ip
                server.port = 53
                table.insert(servers, server)
            end
        end
    end

    while 1 do
        local pos, chars = data:match('()([\r\n].?)', posa)
        if pos then
            if chars == '\r\n' then pos = pos + 1 end
            local line = data:sub(posa, pos - 1)
            _parse(line)
            posa = pos + 1

        else
            local line = data:sub(posa)
            _parse(line)
            break
        end
    end

    SERVERS = servers

    return servers
end

return exports
