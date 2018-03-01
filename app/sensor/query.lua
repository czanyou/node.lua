local utils 	= require('util')
local thread 	= require('thread')
local sqlite 	= require('sqlite3')
local path 		= require('path')

local SHT20_TABLE 	= 'sht20'
local MIN_INTERVAL 	= 60 * 30
local DATABASE_NAME = 'data.db'

local isInited    	= false

local exports = {}

local function get_padding_string(text, length)
	text = tostring(text)
	local len = #text
	if (len < length) then
		return text .. string.rep(' ', length - len)
	end

	return text
end

local function open_database()
	local dirname  = path.dirname(utils.filename())
	local filename = path.join(dirname, DATABASE_NAME)

	local db = sqlite.open(filename)
	if (not db) then
		print('open_database', 'open database failed', filename)
		return
	end

	return db
end

-------------------------------------------------------------------------------
-- add

local function sht20_table_exists(db, name)
	local sql = "SELECT COUNT(*) AS c FROM sqlite_master WHERE type='table' AND name=?"
	local stmt = db:prepare(sql)
	local count = 0
	if (stmt) then
		stmt:bind(name)
		count = stmt:first_cols() or 0
		stmt:close()
	end

	if (count > 0) then
		return true
	end
end

local function sht20_table_init(db)
	local sql = "CREATE TABLE sht20 (id INTEGER, temperature INTEGER, humidity INTEGER, time INTEGER)"

	if (not sht20_table_exists(db, SHT20_TABLE)) then
		db:exec(sql)
	end

	db:close()
end

local function sht20_query_last(db) 
	local sql = "SELECT id,temperature,humidity,time FROM sht20 ORDER BY time DESC"
	local stmt = db:prepare(sql)
	if (stmt) then
		local ret = stmt:first_row()
		stmt:close()
		return ret
	end
end

local function sht20_add(db, temperature, humidity) 
	local id = 0
	local now = os.time()
	local stmt = db:prepare("INSERT INTO sht20 VALUES (?, ?, ?, ?)")
	if (stmt) then
		stmt:bind(id, temperature, humidity, now)
		stmt:exec()
		stmt:close()
	end
end

-------------------------------------------------------------------------------
-- list all

local function view_line1(list, ch)
	local line = '+'
	for i = 1, #list do
		line = line .. string.rep(ch or '-', list[i]) .. '+'
	end

	print(line)
end

local function view_line2(list, title)
	local total = 0
	for i = 1, #list do
		total = total + list[i] + 1
	end

	local line = '| ' .. get_padding_string(title, total - 3) .. ' |'
	print(line)
end

local function view_line3(list, ...)
	local values = { ... }
	local count = #list

	local line = '| '
	for i = 1, count do
		line = line .. get_padding_string(values[i], list[i] - 2) .. ' | '
	end

	print(line)
end

local function sht20_clear(db)
	local sql = "SELECT * FROM sht20 WHERE temperature>?"
	local stmt = db:prepare(sql)
	if (not stmt) then
		return
	end

	stmt:bind(value or 40 * 100)

	for row in stmt:rows() do
		console.log(row)
	end

	stmt:close()

	db:exec("DELETE FROM sht20 WHERE temperature > 40 * 100")
end

local function sht20_list_all(db)
	local date = os.date('*t', time)
	--console.log(date)

	date.day  = date.day - 7
	date.hour = 0
	date.min  = 0
	date.sec  = 0
	start = os.time(date)

	local sql = "SELECT id,temperature,humidity,time FROM sht20 WHERE time>? ORDER BY time ASC"
	local stmt = db:prepare(sql)
	if (not stmt) then
		return
	end

	stmt:bind(start)

	local lastDayString = nil
	local lastHourString = nil

	local cols = { 20, 12, 12 }

	view_line1(cols)
	view_line3(cols, 'Time', 'Temp', 'Humidity')

	for row in stmt:irows() do
		local time 			= row[4]
		local dayString 	= os.date("%Y-%m-%d", time)
		local hourString 	= os.date("%Y-%m-%d %H:00", time)

		local temperature 	= tostring(row[2] / 100) .. "`C"
		local humidity    	= tostring(row[3] / 100) .. "%"

		if (dayString ~= lastDayString) then
			view_line1(cols, '=')
			view_line2(cols, dayString)
			view_line1(cols, '-')

			lastDayString = dayString
		end

		if (hourString ~= lastHourString) then
			lastHourString = hourString
			view_line3(cols, hourString, temperature, humidity)
		end
	end

	view_line1(cols)
	stmt:close()
end

local function sht20_find_range(db, startTime, endTime)
	local sql = "SELECT MIN(temperature),AVG(temperature),MAX(temperature)"
		.. ",MIN(humidity),AVG(humidity),MAX(humidity)"
		.. "FROM sht20 WHERE time>=? AND time<? ORDER BY time ASC"
	local stmt = db:prepare(sql)
	if (not stmt) then
		return
	end

	stmt:bind(startTime, endTime or os.time())

	return stmt:first_irow()
end

local function sht20_find_all(db, mode, offset)
	print('mode', mode, 'offset', offset)

	local startTime, endTime
	local date = os.date('*t')
	local currentDay = date.day
	local days = 1

	local list = {}

	if (mode == 'day') then
		date.hour = 0
		date.min  = 0
		date.sec  = 0

		if (tonumber(offset)) then
			date.day = date.day + tonumber(offset)
		end

		for i = 1, 24 do
			startTime = os.time(date)

			date.hour = date.hour + 1
			endTime = os.time(date)

			local ret = sht20_find_range(db, startTime, endTime)
			if (not ret) then
				break
			end

			local data = {
				startTime   = startTime,
				temperature = math.floor(ret[2] or 0) / 100,
				humidity    = math.floor(ret[5] or 0) / 100
			}

			if (ret[2]) then
				table.insert(list, data)
			end
		end

		return list


	elseif (mode == 'year') then
		days = 12
		date.month  = date.month - days	+ 1

		date.day  = 1
		date.hour = 0
		date.min  = 0
		date.sec  = 0

		for i = 1, days do
			startTime = os.time(date)

			date.month = date.month + 1
			endTime = os.time(date)

			local ret = sht20_find_range(db, startTime, endTime)
			if (not ret) then
				break
			end

			local data = {
				startTime    	= startTime,
				temperature 	= math.floor(ret[2] or 0) / 100,
				min_temperature = math.floor(ret[1] or 0) / 100,
				max_temperature = math.floor(ret[3] or 0) / 100,
				humidity     	= math.floor(ret[5] or 0) / 100
			}

			if (ret[2]) then
				table.insert(list, data)
			end
		end

		return list


	elseif (mode == 'week') then
		days = 7
		date.day  = date.day - days + 1

	elseif (mode == 'month') then
		days = 31
		date.day  = date.day - days + 1
	
	end

	date.hour = 0
	date.min  = 0
	date.sec  = 0

	for i = 1, days do
		startTime = os.time(date)

		date.day = date.day + 1
		endTime = os.time(date)

		local ret = sht20_find_range(db, startTime, endTime)
		if (not ret) then
			break
		end

		local data = {
			startTime    	= startTime,
			temperature 	= math.floor(ret[2] or 0) / 100,
			min_temperature = math.floor(ret[1] or 0) / 100,
			max_temperature = math.floor(ret[3] or 0) / 100,
			humidity     	= math.floor(ret[5] or 0) / 100
		}

		if (ret[2]) then
			table.insert(list, data)
		end
	end

	return list
end

-------------------------------------------------------------------------------
-- exports

function exports.findAll(mode, offset)
	local db = open_database()
	if (db) then
		local ret = sht20_find_all(db, mode, offset)
		db:close()

		--console.log(ret)
		return ret
	end
end

function exports.listALl(startTime, endTime)
	local db = open_database()
	if (db) then
		sht20_list_all(db)
		db:close()
	end
end

function exports.clear(...)
	local db = open_database()
	if (db) then
		sht20_clear(db, ...)
		db:close()
	end
end

function exports.log(temperature, humidity)
	temperature = math.floor(temperature * 100)
	humidity    = math.floor(humidity    * 100)

	local db = open_database()
	if (db) then
		if (not isInited) then
			isInited = true
			sht20_table_init(db)
		end

		local now = os.time()
		local item = sht20_query_last(db) or {}

		local span = math.abs(now - (item.time or 0))
		if (span >= MIN_INTERVAL) then
			sht20_add(db, temperature, humidity)
		end

		db:close()
	end
end

return exports
