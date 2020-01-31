local tap = require("ext/tap")
local test = tap.test

test("console.printBuffer", function()
	local data = string.rep(34, 10)
	console.printBuffer(data)
end)

test("console.printr", function()
	local data = "abcd我的"
	console.printr(data)
end)

test("console.log", function()
	local data = "abcd我的"
	console.log(data, 100, 5.3, true)
end)

test("console.trace", function()
	local data = "abcd我的"
	console.trace(data)
end)

test("console.write", function()
	local data = {}
	console.write(data, "test", nil, 100, true, false, "\n")
end)

test("console.write", function()
	local index = 0
	local timerId = nil
	timerId = setInterval(10, function()
		index = index + 1
		console.write("test", index, "\r")

		if (index >= 10) then
			clearInterval(timerId)
		end
	end)
end)

test("console.stdio", function()
	console.log(console.stdin);
	console.log(console.stdout);
	console.log(console.stderr);
end)

tap.run()
