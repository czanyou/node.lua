local utils = require('utils')
local dump  = console.dump
local strip = console.strip
local ext = require('ext/utils')

require('ext/tap')(function (test)

  test("console.logBuffer", function ()
  	local data = string.rep(34, 10)
  	console.printBuffer(data)
  end)

  test("console.pprint", function ()
  	local data = "abcd我的"
  	console.pprint(data)
  end)

  test("console.log", function ()
  	local data = "abcd我的"
  	console.log(data, 100, 5.3, true)
  end)  

  test("console.trace", function ()
  	local data = "abcd我的"
  	console.trace(data)
  end)

  console.table = function(data)
    local table = ext.table({10, 12, 14})
    table.line()
    table.title("test")
    table.line()
    table.cell("a", "b", 100)
    table.line()
    
  end

  test("console.table", function ()
    local data = {}
    console.table(data)
  end)

  test("console.write", function ()
    local data = {}
    console.write(data, "test", nil, 100, true, false, '\n')
  end)

  test("console.write", function ()
    local index = 0
    local timerId = nil
    timerId = setInterval(100, function()
        index = index + 1
        console.write("test", index, '\r')
        if (index >= 100) then
          clearInterval(timerId)
        end
    end)
  end) 

end)

