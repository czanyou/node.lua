local tap 		= require('ext/tap')

local test = tap.test

-- [[
test("test table insert & remove", function ()
	console.time('test table 1')

	-- 测试 table 性能

	local list = {}

	for i = 1, 1000 * 1000 do
		local value = tostring(i)
		list[#list + 1] = value
	end

	local data = table.concat(list)

	console.timeEnd("test table 1")
end)


test("test table insert & remove", function ()
	console.time('test table 1.1')

	-- 测试 table 性能

	local list = {}

	local insert = table.insert

	for i = 1, 1000 * 1000 do
		local value = tostring(i)
		table.insert(list, value)
	end

	local data = table.concat(list)

	console.timeEnd("test table 1.1")
end)

--]]

-- [[

test("test table insert & remove", function ()
	console.time('test table 1.2')

	-- 测试 table 性能

	local list = StringBuffer:new()

	local insert = table.insert

	for i = 1, 1000 * 1000 do
		local value = tostring(i)
		list:append(" " .. value .. " ")
	end

	local data = list:toString()

	console.timeEnd("test table 1.2")
end)

test("test table insert & remove", function ()
	console.time('test table 1.2')

	-- 测试 table 性能

	local list = StringBuffer:new()

	local insert = table.insert

	for i = 1, 1000 * 1000 do
		local value = tostring(i)
		list:append(" "):append(value):append(" ")
	end

	local data = list:toString()

	console.timeEnd("test table 1.2")
end)

test("test table insert & remove", function ()
	console.time('test table 2')

	-- 测试 table 性能
	local data = ''

	for i = 1, 1000 * 10 do
		local value = tostring(i)
		data = data .. value
	end

	console.timeEnd("test table 2")
end)

--]]

--[[

test("test table insert & remove", function ()
	console.time('test table 3')

	-- 测试 table 性能
	local data = ''

	for i = 1, 1000 * 1000 do
		local value = "34df" .. tostring(i) .. " end"
	end

	console.timeEnd("test table 3")
end)

test("test table insert & remove", function ()
	console.time('test table 4')

	-- 测试 table 性能
	local data = ''

	for i = 1, 1000 * 1000 do
		local value = table.concat({"34df", tostring(i), " end"})
	end

	console.timeEnd("test table 4")
end)

--]]



test("test table insert & remove", function ()
	console.time('test table 6')

	-- 测试 table 性能
	local data = 'aaaaaaa'
	local list = {}


	for i = 1, 1000 * 1 do
		data = data .. string.rep(tostring(i % 10 + i), 1000)
		data = data:sub(101)
	end

	console.timeEnd("test table 6")

	print(#data)
end)

test("test table insert & remove", function ()
	console.time('test table 8')

	-- 测试 table 性能
	local data = 'aaaaaaa'
	local list = { data }


	for i = 1, 1000 * 100 do
		list[#list + 1] = string.rep(tostring(i % 10 + i), 1000)
		table.remove(list, 1)
	end

	console.timeEnd("test table 8")

	print(#list)
end)


test("test table insert & remove", function ()
	console.time('test table 7')

	-- 测试 table 性能
	local buffer = require('buffer')
	local data = buffer.Buffer:new(1024)
	print(data:limit())
	data:write('aaaaaaa')


	for i = 1, 1000 * 100 do
		if (data:length() - data:limit()) < 100 then
			data:compress()
		end


		data:write(string.rep(tostring(i % 10 + 1), 1000))
		data:toString(1, 100)
		data:skip(100)

		--print(data:position())
	end

	console.timeEnd("test table 7")

	print(data:size())
end)

tap.run()
