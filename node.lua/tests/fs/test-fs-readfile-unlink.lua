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

require('ext/tap')(function(test)
  local fs     = require('fs')
  local path   = require('path')
  local Buffer = require('buffer').Buffer

  local dirName = path.join(module.dir, 'fixtures', 'test-readfile-unlink')
  local fileName = path.join(dirName, 'test.bin')

  local bufStr = string.rep(string.char(42), 512 * 1024)
  local buf = Buffer:new(bufStr)
  print('buf', buf:length())

  test('fs readfile unlink', function()

    local ok, err

    ok, err = pcall(fs.mkdirSync, dirName, '0777')
    if not ok then
      assert(err.code == 'EEXIST')
    end

    fs.writeFileSync(fileName, buf:toString())
    fs.readFile(fileName, function(err, data)
      assert(err == nil)
      assert(#data == buf:length())
      assert(string.byte(data, 1) == 42)

      fs.unlink(fileName, function()
        fs.rmdirSync(dirName)
      end)
    end)
  end)
end)
