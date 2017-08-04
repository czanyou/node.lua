
local spawn = require('child_process').spawn
local net   = require('net')
local uv    = require('uv')

require('ext/tap')(function(test)

  test('environment subprocess', function(expect)
    local child, options, onStdout, onExit, onEnd, data

    options = {
      env = { TEST1 = 1 }
    }

    data = ''

    if os.platform() == 'win32' then
      child = spawn('cmd.exe', {'/C', 'set'}, options)
    else
      child = spawn('env', {}, options)
    end

    function onStdout(chunk)
      --p('stdout', chunk)
      data = data .. chunk
    end

    function onExit(code, signal)
      p('exit', code, signal)
      assert(code == 0)
      assert(signal == 0)
    end

    function onEnd()
      assert(data:find('TEST1=1'))
      p('end and found')
    end

    child.stdout:once('end', expect(onEnd))
    child.stdout:on('data', onStdout)
    child:on('exit', expect(onExit))
    child:on('close', expect(onExit))
  end)

  test('invalid command', function(expect)
    local child, onError

    -- disable on windows, bug in libuv
    --if os.platform() == 'win32' then return end

    function onError(err)
      p('error', err)
      assert(err)
    end

    child = spawn('skfjsldkfjskdfjdsklfj')
    child:on('error', expect(onError))
    child.stdout:on('error', expect(onError))
    child.stderr:on('error', expect(onError))
  end)

  test('invalid command verify exit callback', function(expect)
    local child, onExit, onClose

    -- disable on windows, bug in libuv
    --if os.platform() == 'win32' then return end

    function onExit() p('exit') end
    function onClose() p('close') end

    child = spawn('skfjsldkfjskdfjdsklfj')
    child:on('exit', expect(onExit))
    child:on('close', expect(onClose))
  end)

  test('process.env pairs', function()
    local key = "LUVIT_TEST_VARIABLE_1"
    local value = "TEST1"
    local iterate, found

    function iterate()
      for k, v in pairs(process.env) do
        --p(k, v)
        if k == key and v == value then found = true end
      end
    end

    process.env[key] = value
    found = false
    iterate()
    assert(found)

    process.env[key] = nil
    found = false
    iterate()
    assert(process.env[key] == nil)
    assert(found == false)
  end)

  test('child process no stdin', function(expect)
    local child, onData, options

    options = {
      stdio = {
        nil,
        net.Socket:new({ handle = uv.new_pipe(false) }),
        net.Socket:new({ handle = uv.new_pipe(false) })
      }
    }

    function onData(data) 
      p('data', data) 
    end

    if os.platform() == 'win32' then
      child = spawn('cmd.exe', {'/C', 'set'}, options)
    else
      child = spawn('env', {}, options)
    end
    child:on('data', onData)
    child:on('exit', expect(function() 
      p('exit')
    end))
    child:on('close', expect(function()
      p('close')
    end))
  end)

  test('child process (no stdin, no stderr, stdout) with close', function(expect)
    local child, onData, options

    options = {
      stdio = {
        nil,
        net.Socket:new({ handle = uv.new_pipe(false) }),
        nil
      }
    }

    function onData(data) 
      p('data', data) 
    end

    if os.platform() == 'win32' then
      child = spawn('cmd.exe', {'/C', 'set'}, options)
    else
      child = spawn('env', {}, options)
    end
    child:on('data', onData)
    child:on('close', expect(function(exitCode) 
      p('close', exitCode)
      assert(exitCode == 0) 
    end))
  end)
end)

