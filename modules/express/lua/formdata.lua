--[[

Copyright 2016-2020 The Node.lua Authors. All Rights Reserved.

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
local core 	 = require('core')
local buffer = require('buffer')

local exports = { }

---@class FormData
local FormData = core.Emitter:extend()
exports.FormData = FormData

local STATE_START 			= 0
local STATE_BOUNDARY_START 	= 1
local STATE_BOUNDARY_VALUE 	= 2
local STATE_BOUNDARY_END  	= 3
local STATE_HEADER_START  	= 4
local STATE_HEADER_VALUE  	= 5
local STATE_HEADER_END  	= 6

local STATE_HEADER_NAME  	= 60
local STATE_HEADER_NAME_END = 61
local STATE_HEADER_DATA  	= 62
local STATE_HEADER_DATA_END	= 63
local STATE_FEILD_NAME		= 64
local STATE_FEILD_NAME_END	= 65
local STATE_FEILD_VALUE		= 66
local STATE_FEILD_QVALUE	= 67
local STATE_FEILD_QVALUE_END= 68

local STATE_DATA_START 		= 7
local STATE_DATA 			= 8
local STATE_END				= 9

function FormData:initialize(contentLength)
	local size = 1024
	if (contentLength and contentLength > size) then
		size = contentLength + 1024
	end

	self.buffer 		= buffer.Buffer:new(size)
	self.state  		= 0
	self.findState 		= 0
	self.headerState 	= 0
	self.findIndex  	= 0
	self.headerIndex  	= 0
	self.dataIndex  	= 0
	self.boundaryIndex  = 0
	self.boundary       = nil
end

function FormData:error(error)
	print('error', error)

end

function FormData:parse(request)

end

function FormData:setState(state)
	self.state = state
	--print('setState', state)
end

function FormData:setFindState(state)
	self.findState = state
	--print('findState', state)
end

function FormData:getValue(i, index, tail)
	local offset = i - index + 1
	local limit  = i - 1 - (tail or 0)
	return self.buffer:toString(offset, limit)
end

function FormData:processData2(data)
	if (not data) or (#data <= 0) then
		return
	end

	local buffer   = self.buffer;
	local startPos = buffer:size() + 1
	local endPos   = startPos + #data - 1

	buffer:putBytes(data)
	
	-- console.log('processData', data, '===')
	-- console.log('processData', #data, startPos, endPos)

	local expandSize  = 0

	local i = startPos
	while (i <= endPos) do
		local c = buffer:read(i)
		--print(string.char(c), c)

		local state = self.state
		if (state == STATE_START) then
			if (c == 45) then -- '-'
				self:setState(STATE_BOUNDARY_START)
				expandSize = i
			end

		elseif (state == STATE_BOUNDARY_START) then
			if (c == 45) then -- '-'
				self:setState(STATE_BOUNDARY_VALUE)
				expandSize   = i
				self.boundaryIndex = 0

			else
				self:setState(STATE_START)
			end

		elseif (state == STATE_BOUNDARY_VALUE) then
			--print(string.char(c), c)
			self.boundaryIndex = self.boundaryIndex + 1

			if (c == 13 or c == 10) then -- '\r'
				self:setState(STATE_BOUNDARY_END)
				
				self.boundary = self:getValue(i, self.boundaryIndex)
				expandSize = i

				--console.log('boundary', self.boundary)

				if (c == 10) then
					self:setState(STATE_HEADER_START)
				end
			end

		elseif (state == STATE_BOUNDARY_END) then
			if (c == 10) then -- '\n'
				self:setState(STATE_HEADER_START)
			else
				return self:error('STATE_BOUNDARY_END')
			end

		elseif (state == STATE_HEADER_START) then
			self.headerIndex = 1

			self.headerState = STATE_HEADER_NAME

			if (c == 13) then -- '\r'
				self:setState(STATE_DATA_START)
				expandSize = i

			elseif (c == 10) then -- '\n'
				expandSize = i

				self:setState(STATE_DATA)
				self.findState = STATE_START
				self.dataIndex = 0

			else 
				self:setState(STATE_HEADER_VALUE)
			end

		elseif (state == STATE_HEADER_VALUE) then
			self.headerIndex = self.headerIndex + 1

			--print('header', c, string.char(c))

			if (c == 13 or c == 10) then -- '\r'
				
				self:setState(STATE_HEADER_END)
				if (c == 10) then -- '\n'
					self:setState(STATE_HEADER_START)
				end
				expandSize = i

				local data = self:getValue(i, self.headerIndex)
				if (data) then
					--print('header value',  '[' .. data .. ']')
					self:emit('header-value', data)
				end

			else
				if (self.headerState == STATE_HEADER_NAME) then
					if (c == 58) then -- ':'
						self.headerState = STATE_HEADER_NAME_END

						local data = self:getValue(i, self.headerIndex)
						--print('Header name', data)
						self:emit('header-name', data)

						self.headerIndex = 0
					end

				elseif (self.headerState == STATE_HEADER_NAME_END) then
					if (c ~= 32) then -- ' '
						self.headerState = STATE_HEADER_DATA

					else 
						self.headerIndex = 0
					end

				elseif (self.headerState == STATE_HEADER_DATA) then
					if (c == 59) then -- ';'
						local data = self:getValue(i, self.headerIndex)
						--print('Header value', data)
						self:emit('header-value', data)

						self.headerState = STATE_HEADER_DATA_END
						self.headerIndex = 0
					end

				elseif (self.headerState == STATE_HEADER_DATA_END) then
					if (c ~= 32) then -- ' '
						self.headerState = STATE_FEILD_NAME

					else 
						self.headerIndex = 0
					end

				elseif (self.headerState == STATE_FEILD_NAME) then	
					if (c == 61) then -- '='
						self.headerState = STATE_FEILD_NAME_END

						local data = self:getValue(i, self.headerIndex)
						--print('Header feild', data)
						self:emit('feild-name', data)
						self.headerIndex = 0
					end

				elseif (self.headerState == STATE_FEILD_NAME_END) then
					if (c ~= 32) then -- ' '
						self.headerState = STATE_FEILD_VALUE
						self.headerIndex = 1

						if (c == 34) then -- '"'
							self.headerState = STATE_FEILD_QVALUE
							self.headerIndex = 0
						end

					else 
						self.headerIndex = 0
					end


				elseif (self.headerState == STATE_FEILD_VALUE) then	
					if (c == 59) then -- ';'
						local data = self:getValue(i, self.headerIndex)
						--print('Header value', data)
						self:emit('feild-value', data)

						self.headerState = STATE_HEADER_DATA_END
						self.headerIndex = 0
					end

				elseif (self.headerState == STATE_FEILD_QVALUE) then	
					if (c == 34) then -- '"'
						local data = self:getValue(i, self.headerIndex)
						--print('Header value', data)
						self:emit('feild-value', data)

						self.headerState = STATE_FEILD_QVALUE_END
						self.headerIndex = 0
					end

				elseif (self.headerState == STATE_FEILD_QVALUE_END) then
					if (c == 59) then -- ';'
						self.headerState = STATE_HEADER_DATA_END
						self.headerIndex = 0
					end
				end
			end

		elseif (state == STATE_HEADER_END) then	
			if (c == 10) then -- '\n'
				expandSize = i
				self:setState(STATE_HEADER_START)

			else 
				self:error('STATE_HEADER_END')
			end

		elseif (state == STATE_DATA_START) then
			if (c == 10) then -- '\n'
				expandSize = i

				self:setState(STATE_DATA)
				self.findState = STATE_START
				self.dataIndex = 0
			end

		elseif (state == STATE_DATA) then
			self.dataIndex = self.dataIndex + 1

			--print('data', i, c)
			if (self.findState == STATE_START) then
				if (c == 45) then -- '-'
					self:setFindState(STATE_BOUNDARY_START)
					self.findIndex = 0
				else
					-- [[
					local pos = buffer:indexOf('-', i)
					if (pos >= 1) then
						print('data', i, c, state, pos)
						self:setFindState(STATE_BOUNDARY_START)
						self.findIndex = 0

						i = i + pos - 1
						self.dataIndex = self.dataIndex + pos
					end
					--]]
				end

			elseif (self.findState == STATE_BOUNDARY_START) then
				if (c == 45) then -- '-'
					self:setFindState(STATE_BOUNDARY_VALUE)
					self.findIndex = 0

				else 
					self:setFindState(STATE_START)
				end

			elseif (self.findState == STATE_BOUNDARY_VALUE) then
				self.findIndex = self.findIndex + 1

				if (self.findIndex <= #self.boundary) then
					local data = self.boundary:byte(self.findIndex)
					--print('data', data, c, self.findIndex, #self.boundary)

					if (data ~= c) then
						self:setFindState(STATE_START)
					end

				elseif (c == 13 or c == 10 or c == 45) then -- '\r\n-'
					self:setFindState(STATE_BOUNDARY_END)
					
					--console.log('boundary', self.boundary)

					if (c == 10) then -- '\n'
						self:setFindState(STATE_START)
						self:setState(STATE_HEADER_START)

					elseif (c == 45) then -- '\n'
						self:setFindState(STATE_START)
						self:setState(STATE_END)
					end

					local offset = i - self.dataIndex + 1
					local limit  = i - self.findIndex - 2 -- -2
					local data = buffer:toString(offset, limit)

					expandSize = i
					console.log('expandSize', expandSize)

					self:emit('file', data)

					--console.log('findMark', i, self.dataIndex, self.findIndex, data)
				end

			elseif (self.findState == STATE_BOUNDARY_END) then
				if (c == 10) then -- '\n'
					self:setFindState(STATE_START)
					self:setState(STATE_HEADER_START)

				else
					self:error('STATE_BOUNDARY_END')
				end
			end
		end

		i = i + 1
	end

	buffer:skip(expandSize)
end

function FormData:processData(data)
	if (not data) or (#data <= 0) then
		return
	end

	local buffer = self.buffer;
	buffer:putBytes(data)

	-- console.log(buffer:position(), buffer:limit())

	local function parseHeaderLine(token)
		local pos = string.find(token, ':')
		if not (pos >= 1) then
			return
		end

		local name = string.sub(token, 1, pos - 1)
		local value = string.sub(token, pos + 1)

		self:emit('header-name', name)

		local items = string.split(value, ';')
		for index, item in ipairs(items) do
			if (index == 1) then
				item = string.trim(item)

				self:emit('header-value', item)
			else
				pos = string.find(item, '=')
				if (pos >= 1) then
					name = string.sub(item, 1, pos - 1)
					value = string.sub(item, pos + 1)
					name = string.trim(name)
					self:emit('feild-name', name)

					if (#value >= 2) and (value:byte(1) == 34) then
						value = string.sub(value, 2, #value - 1)
					end

					self:emit('feild-value', value)
				end
			end
			-- console.log('parseHeader', index, string.trim(item))
		end
	end

	local function parseHeader(data)
		local tokens = string.split(data, '\r\n')

		for _, token in ipairs(tokens) do
			parseHeaderLine(token)
		end
	end

	while (true) do
		local state = self.state
		if (state == STATE_START) then
			local pos = buffer:indexOf('\r\n')
			if (pos > 1) then
				local data = buffer:toString(1, pos - 1)
				-- console.log('boundary', pos, data)

				self.boundary = '\r\n' .. data
				buffer:skip(pos - 1)

				self:setState(STATE_HEADER_START)

			else
				break
			end

		elseif (state == STATE_HEADER_START) then
			local pos = buffer:indexOf('\r\n\r\n')
			if (pos >= 1) then
				if (pos > 1) then
					local data = buffer:toString(3, pos - 1)
					self.header = data
					-- console.log('header', pos, data)

					parseHeader(data)
				end

				buffer:skip(pos + 4 - 1)
				-- console.log('buffer', buffer:toString())
				self:setState(STATE_DATA_START)

			else
				break
			end

		elseif (state == STATE_DATA_START) then
			local pos = buffer:indexOf(self.boundary)
			if (pos > 1) then
				local data = buffer:toString(1, pos - 1)
				-- console.log('data', pos, #data, data)

				self:emit('file', data)

				buffer:skip(pos)
				buffer:skip(#self.boundary - 1)

				self:setState(STATE_DATA)
			else
				break
			end

		elseif (state == STATE_DATA) then
			if (buffer:size() >= 2) then
				local data = buffer:toString(1, 2)
				-- console.log('buffer', data, buffer:toString())

				if (data == '\r\n') then
					self:setState(STATE_HEADER_START)

				else
					self:setState(STATE_END)
				end
			else
				break
			end
		else
			break
		end
	end
end

return exports
