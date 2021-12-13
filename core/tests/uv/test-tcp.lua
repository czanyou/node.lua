local tap = require('util/tap')
local test = tap.test

local isWindows = os.platform() == "win32"
local sockname = "/tmp/test.sock"
if (isWindows) then
    sockname = "\\\\?\\pipe\\uv-test"
end

--[[
test("basic tcp server and client", function(expect, uv)
    local server = uv.new_tcp()
    uv.tcp_bind(server, "::", 0)
    uv.listen(server, 128, expect(function(err)
            --console.log("server on connection", server)
            assert(not err, err)
            uv.close(server)
    end))

    local address = uv.tcp_getsockname(server)
    --console.log{server=server,address=address}
    local client = uv.new_tcp()
    local req = uv.tcp_connect(client, "::1", address.port, expect(function(err)
            --console.log("client on connect", client, err)
            assert(not err, err)
            uv.shutdown(client, expect(function(err)
                    -- console.log("client on shutdown", client, err)
                    assert(not err, err)
                    uv.close(client, expect(function()
                        console.log("client on close", client)
                    end))
            end))
    end))
--console.log{client=client,req=req}
end)
--]]

test("basic pipe server and client", function(expect, uv)
    local server = uv.new_pipe(false)
    local ret, err = uv.pipe_bind(server, sockname)
    assert(ret, err)
    uv.listen(server, 128, expect(function(err)
            --console.log("server on connection", server)
            assert(not err, err)
            uv.close(server)
    end))
    local address = uv.pipe_getsockname(server)
    console.log{server = server, address = address}

    local client = uv.new_pipe(false)
    local req = uv.pipe_connect(client, sockname, expect(function(err)--console.log("client on connect", client, err)
        assert(not err, err)
        uv.shutdown(client, expect(function(err)
                -- console.log("client on shutdown", client, err)
                assert(not err, err)
                uv.close(client, expect(function()
                    console.log("client on close", client)
                end))
        end))
    end))
--console.log{client=client,req=req}
end)

test("tcp echo server and client", function(expect, uv)
    -- create a server socket
    local server = uv.new_tcp()
    assert(uv.tcp_bind(server, "127.0.0.1", 0))
    assert(uv.listen(server, 1, expect(function()
        local client = uv.new_tcp()
        assert(uv.accept(server, client))

        -- wait hello from client
        assert(uv.read_start(client, expect(function(err, data)
                --console.log("server read", {err=err,data=data})
                assert(not err, err)
                if data then
                    assert(uv.write(client, data))
                else
                    assert(uv.read_stop(client))
                    uv.close(client)
                    uv.close(server)
                end
        end, 2)))
    end)))
    
    local address = uv.tcp_getsockname(server)
    --console.log{server=server,address=address}
    -- create a client socket
    local socket = assert(uv.new_tcp())
    assert(uv.tcp_connect(socket, "127.0.0.1", address.port, expect(function()
            -- wait hello response from server
            assert(uv.read_start(socket, expect(function(err, data)
                console.log("client read:", {err = err, data = data})
                assert(not err, err)
                assert(uv.read_stop(socket))
                uv.close(socket)
            end)))
            -- send hello to server
            local req = assert(uv.write(socket, "Hello", function(err)
                    --console.log("client onwrite", socket, err)
                    assert(not err, err)
            end))
    end)))
end)

test("pipe echo server and client", function(expect, uv)
    -- create a server socket
    local server = uv.new_pipe(false)
    assert(uv.pipe_bind(server, sockname))
    assert(uv.listen(server, 1, expect(function()
        local client = uv.new_pipe(false)
        assert(uv.accept(server, client))

        -- wait hello from client
        assert(uv.read_start(client, expect(function(err, data)
                --console.log("server read", {err=err,data=data})
                assert(not err, err)
                if data then
                    assert(uv.write(client, data))
                else
                    assert(uv.read_stop(client))
                    uv.close(client)
                    uv.close(server)
                end
        end, 2)))
    end)))

    local address = uv.pipe_getsockname(server)
    --console.log{server=server,address=address}
    -- create a client socket
    local socket = assert(uv.new_pipe(false))
    assert(uv.pipe_connect(socket, sockname, expect(function()
            -- wait hello response from server
            assert(uv.read_start(socket, expect(function(err, data)
                console.log("client read:", {err = err, data = data})
                assert(not err, err)
                assert(uv.read_stop(socket))
                uv.close(socket)
            end)))
            -- send hello to server
            local req = assert(uv.write(socket, "Hello", function(err)
                    --console.log("client onwrite", socket, err)
                    assert(not err, err)
            end))
    end)))
end)

test("tcp echo server and client with methods", function(expect, uv)
    -- create a server socket
    local server = uv.new_tcp()
    assert(server:bind("127.0.0.1", 0))
    assert(server:listen(1, expect(function()
        local client = uv.new_tcp()
        assert(server:accept(client))

        -- wait hello form client
        assert(client:read_start(expect(function(err, data)
                --console.log("server read", {err=err,data=data})
                assert(not err, err)
                if data then
                    assert(client:write(data))
                else
                    assert(client:read_stop())
                    client:close()
                    server:close()
                end
        end, 2)))
    end)))
    local address = server:getsockname()
    --console.log{server=server,address=address}
    -- create a client socket
    local socket = assert(uv.new_tcp())
    assert(socket:connect("127.0.0.1", address.port, expect(function()
            -- wait hello response form server
            assert(socket:read_start(expect(function(err, data)
                console.log("client read:", {err = err, data = data})

                assert(data == "Hello")
                assert(not err, err)
                assert(socket:read_stop())
                socket:close()
            end)))
            -- send a hello to server
            local req = assert(socket:write("Hello", function(err)
                    --console.log("client onwrite", socket, err)
                    assert(not err, err)
            end))
    end)))
end)

test("uv.tcp_bind invalid ip address", function(expect, uv)
    local ip = "127.0.0.100005"
    local server = uv.new_tcp()
    local status, err = pcall(function()
        uv.tcp_bind(server, ip, 1000)
    end)
    
    assert(not status)
    console.log("error", err)
    assert(err:find(ip))
    uv.close(server)
end)
