require('ext/tap')(function (test)

  local path  = require('path')
  local spawn = require('child_process').spawn
  local timer = require('timer')

  local __dirname = module.dir

  test("tls process detached", function()
    local childPath = path.join(__dirname, 'fixtures', 'parent-process-nonpersistent.lua')
    local persistentPid = -1

    if os.platform() == 'win32' then
      return
    end

    local argv = process.argv
    local child = spawn(argv[0], { childPath })
    child.stdout:on('data', function(data)
      persistentPid = tonumber(data)
    end)
    timer.setTimeout(1000, function()
      local err = pcall(function()
        process.kill(child.pid)
      end)
      --process.kill(persistentPid)
    end)

  --[[
    process:on('exit', function()
      assert(persistentPid ~= -1)
      local err = pcall(function()
        process.kill(child.pid)
      end)
      process.kill(persistentPid)
    end)
  --]]
  end)
  
end)
