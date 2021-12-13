--[[

Copyright 2012-2015 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License")
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

local tap = require('util/tap')
local test = tap.test

local fs = require('fs')
local path = require('path')
local string = require('string')

local tmp = os.tmpdir

local dir = path.join(tmp, 'tmp')
local filename = path.join(dir, 'truncate-file.txt')
local data = string.rep('x', 1024 * 16)

test('fs truncate', function()
    local stat
    local _, err = fs.statSync(dir)
    if err then fs.mkdirpSync(dir, "0755") end

    -- truncateSync
    fs.writeFileSync(filename, data)
    stat = fs.statSync(filename)
    assert(stat.size == 1024 * 16)

    fs.truncateSync(filename, 1024)
    stat = fs.statSync(filename)
    assert(stat.size == 1024)

    fs.truncateSync(filename)
    stat = fs.statSync(filename)
    assert(stat.size == 0)

    -- ftruncateSync
    fs.writeFileSync(filename, data)
    local fd = fs.openSync(filename, 'r+')

    stat = fs.statSync(filename)
    assert(stat.size == 1024 * 16)

    fs.ftruncateSync(fd, 1024)
    stat = fs.statSync(filename)
    assert(stat.size == 1024)

    fs.ftruncateSync(fd)
    stat = fs.statSync(filename)
    assert(stat.size == 0)

    fs.closeSync(fd)

    local function testTruncate(cb)
      fs.writeFile(filename, data, function(er)
        if er then
          return cb(er)
        end
        fs.stat(filename, function(er, stat)
          if er then
            return cb(er)
          end
          assert(stat.size == 1024 * 16)

          fs.truncate(filename, 1024, function(er)
            if er then
              return cb(er)
            end
            fs.stat(filename, function(er, stat)
              if er then
                return cb(er)
              end
              assert(stat.size == 1024)

              fs.truncate(filename, function(er)
                if er then
                  return cb(er)
                end
                fs.stat(filename, function(er, stat)
                  if er then
                    return cb(er)
                  end
                  assert(stat.size == 0)
                  cb()
                end)
              end)
            end)
          end)
        end)
      end)
    end


    local function testFtruncate(cb)
      fs.writeFile(filename, data, function(er)
        if er then
          return cb(er)
        end
        fs.stat(filename, function(er, stat)
          if er then
            return cb(er)
          end
          assert(stat.size == 1024 * 16)

          fs.open(filename, 'w', function(er, fd)
            if er then
              return cb(er)
            end
            fs.ftruncate(fd, 1024, function(er)
              if er then
                return cb(er)
              end
              fs.stat(filename, function(er, stat)
                if er then
                  return cb(er)
                end
                assert(stat.size == 1024)

                fs.ftruncate(fd, function(er)
                  if er then
                    return cb(er)
                  end
                  fs.stat(filename, function(er, stat)
                    if er then
                      return cb(er)
                    end
                    assert(stat.size == 0)
                    fs.close(fd, cb)
                    fs.unlinkSync(filename)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end

    -- async tests
    local success = 0
    testTruncate(function(er)
      if er then
        return er
      end
      success = success + 1
      testFtruncate(function(er)
        if er then
          return er
        end
        success = success + 1
      end)
    end)
--[[
    process:on('exit', function()
      assert(success == 2)
      console.log('ok')
    end)
--]]
end)

tap.run()
