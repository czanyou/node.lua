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
    local fs = require('fs')
    local uv = require('uv')
    local path = require('path')
    local utils = require('util')

    local f =  uv.cwd() --module.path
    local dirname = utils.dirname()
    local tmp = os.tmpdir

    test('fs.copyfile', function()
      
      local src = path.join(dirname, 'run.lua')
      local dest = path.join(tmp, 'run1.test')

      console.log(src, dest);

      fs.copyfile(src, dest, function(err, y)
          console.log(err, y)
          os.remove(dest)
      --  assert(y)
      end)

      local dest2 = path.join(tmp, 'run2.test')
      assert(fs.copyfileSync(src, dest2))

      os.remove(dest2)
    end)
end)