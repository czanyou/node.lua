local json 		= require('json')
local path 		= require('path')
local thread 	= require('thread')
local utils 	= require('utils')

local sqlite 	= require('sqlite3')

local DATA_TABLE 	= 'data'
local STAT_TABLE 	= 'stat'
local DATABASE_NAME = 'data.db'

local isInited = false
local data_stream_latest

--[[
传感器数据流和数据点记录和查询模块

这个模块使用 Sqlite 数据库来记录传感器数据流数据

--]]

local exports = {}

-- 统计周期
exports.HOUR  	= 'hour' -- 过云一小时内
exports.DAY  	= 'day'  -- 过去一天内
exports.WEEK  	= 'week' -- 过去一周期间
exports.MONTH  	= 'month'-- 过去一月期间
exports.YEAR  	= 'year' -- 过去一年期间

-- 统计方法
exports.AVG  	= 'avg'  -- 某时间段平均值
exports.MIN  	= 'min'  -- 某时间段的最小值
exports.MAX  	= 'max'  -- 某时间段的最大值

-- 数据流类型
local types = {}
types.temperature	= 101
types.humidity		= 120

exports.types   = types


local function paddingZero(value)
	if (value < 10) then
		return '0' .. value
	else
		return value
	end
end

-------------------------------------------------------------------------------
-- open the database

local function data_stream_open(name)
	if (not name) then
		name = DATABASE_NAME
	end

	local filename = name
	if (name ~= ':memory:') then
		local dirname  = exports.dirname or utils.dirname()
		filename = path.join(dirname, name)
	end

	local db = sqlite.open(filename)
	if (not db) then
		print('data_stream_open', 'open database failed', filename)
		return
	end

	-- print('database: ' .. filename)

	return db
end

-------------------------------------------------------------------------------
-- data stream type

local function data_stream_type(name)
	if (tonumber(name)) then
		return name

	else
		return types[name] or name
	end
end

-------------------------------------------------------------------------------
-- stat

local function data_stat_add(db, type, method, range, value, timestamp) 
	local sql = "INSERT INTO stat(type, method, range, value, timestamp)"
		.. " VALUES (?, ?, ?, ?, ?)"
	local stmt, err = db:prepare(sql)
	if (not stmt) then
		return stmt, err
	end

	stmt:bind(data_stream_type(type), method, range, value, timestamp)
	stmt:exec()
	stmt:close()
end

local function data_stat_get(db, type, method, range, startTime)
	local sql = "SELECT id,type,method,range,value,timestamp FROM stat"
		.. " WHERE type=? AND method=? AND range=? AND timestamp=?"
	local stmt, err = db:prepare(sql)
	if (not stmt) then
		return stmt, err
	end

	stmt:bind(type, method, range, startTime)
	local ret = stmt:first_row()

	stmt:close()

	return ret

end

local function data_stat_list(db, type, method, range, startTime, endTime)
	limit = limit or 20

	local where = nil
	local sql = "SELECT id,type,method,range,value,timestamp FROM stat"

	local stmt, err = db:prepare(sql)
	assert(stmt, err)

	local ret = {}

	local index = 0
	for row in stmt:rows() do
		table.insert(ret, row)

		index = index + 1
		if (index > limit) then
			break
		end
	end

	stmt:close()

	return ret
end

-------------------------------------------------------------------------------
-- add

local function data_stream_add(db, type, value, timestamp, interval) 
	if (tonumber(value) == nil) then
		return
	end

	-- check count
	if (timestamp) then
		local sql = "SELECT COUNT(id) AS id FROM data WHERE type=? AND timestamp=?"
		local stmt, err = db:prepare(sql)
		assert(stmt, err)

		stmt:bind(data_stream_type(type), timestamp)

		local count = stmt:first_cols() or 0
		stmt:close()

		if (count > 0) then
			return
		end
	end

	timestamp = timestamp or os.time()
	if (interval) then
		local ret = data_stream_latest(db, type)
		if (ret and ret.timestamp) then
			local span = math.abs(timestamp - ret.timestamp)
			if (span < interval) then
				--print('interval', span, interval)
				return
			end
		end
	end

	-- max id
	local sql = "SELECT MAX(id) AS id FROM data"
	local stmt, err = db:prepare(sql)
	assert(stmt, err)

	local id = (stmt:first_cols() or 0) + 1
	stmt:close()

	-- insert
	local sql = "INSERT INTO data(id, type, value, timestamp) VALUES (?, ?, ?, ?)"
	local stmt, err = db:prepare(sql)
	assert(stmt, err)

	stmt:bind(id, data_stream_type(type), value, timestamp)
	stmt:exec()
	stmt:close()
end

-------------------------------------------------------------------------------
-- clear

local function data_stream_clear(db)
	local sql = "SELECT * FROM data WHERE type=? AND value>?"
	local stmt = db:prepare(sql)
	if (not stmt) then
		return
	end

	stmt:bind(types.temperature, value or 50)

	for row in stmt:rows() do
		console.log(row)
	end

	stmt:close()

	db:exec("DELETE FROM data WHERE type=" .. types.temperature .. " AND value > 50")

	db:exec("DELETE FROM stat")

end

-------------------------------------------------------------------------------
-- exists

local function data_stream_exists(db, name)
	local sql = "SELECT COUNT(*) AS c FROM sqlite_master WHERE type='table' AND name=?"
	local stmt = db:prepare(sql)
	local count = 0
	if (stmt) then
		stmt:bind(name)
		count = stmt:first_cols() or 0

		--print('data_stream_exists: count', count)
		stmt:close()
	end

	if (count > 0) then
		return true
	end
end

local function data_stream_get_time_range(mode, offset)
	local date = os.date('*t')
	offset = tonumber(offset)

	local startTime, endTime
	date.sec   = 0
	date.min   = 0

	if (mode == 'day') then
		if (offset) then
			date.day = date.day + offset
		end

		date.hour = date.hour + 1
		endTime = os.time(date)

		date.hour = date.hour - 24
		startTime = os.time(date)

	elseif (mode == 'year') then
		date.hour  = 0

		if (offset) then
			date.year = date.year + offset
		end
		endTime = os.time(date)
	
		date.day  = 1
		date.year = date.year - 1
		startTime = os.time(date)

	elseif (mode == 'month') then
		date.hour  = 0

		if (offset) then
			date.month = date.month + offset
		end
		endTime = os.time(date)

		date.month = date.month - 1
		startTime = os.time(date)

	elseif (mode == 'week') then
		date.hour  = 0
		local count = 7

		if (offset) then
			date.day = date.day + offset * count
		end
		endTime = os.time(date)

		date.day = date.day - count
		startTime = os.time(date)

	else
		if (offset) then
			date.day = date.day + offset
		end

		startTime = os.time(date)

		date.day = date.day + 1
		endTime = os.time(date)		
	end

	return startTime, endTime
end

local function data_stream_stat_group_by(mode)
	if (mode == 'day') then
		return "timestamp - (timestamp % 120)"

	elseif (mode == 'year') then
		return "strftime('%Y-%m-%d', timestamp, 'unixepoch', 'localtime')"

	elseif (mode == 'month') then
		return "timestamp - (timestamp % 3600)"

	elseif (mode == 'week') then
		return "timestamp - (timestamp % 1800)"

	end

	return "strftime('%Y-%m-%d', timestamp, 'unixepoch', 'localtime')"
end

local function data_stream_stat(db, streamType, mode, offset)
	mode   = mode or exports.DAY
	offset = offset or 0

	print('===')
	print('data_stream_stat', 'mode:', mode, 'offset:', offset)

	local startTime, endTime = data_stream_get_time_range(mode, offset)

	local groupBy = " GROUP BY " .. data_stream_stat_group_by(mode)
	local orderBy = " ORDER BY timestamp ASC"
	local selectBy = " AVG(value) avg,COUNT(value) count,"

	local sql = "SELECT" .. selectBy
		.. " MIN(timestamp) start"
		.. " FROM data"
		.. " WHERE type=? AND timestamp>=? AND timestamp<?"
		.. groupBy
		.. orderBy

	console.log(sql)

	local stmt, err = db:prepare(sql)
	assert(stmt, err)

	local streamId = data_stream_type(streamType)
	stmt:bind(streamId, startTime, endTime)
	console.log(streamId, startTime, endTime)

	local list = {}
	for row in stmt:rows() do
		row.date = os.date("%Y-%m-%d %H:%M", row.start)
		table.insert(list, row)
	end

	return list
end

-------------------------------------------------------------------------------
-- import

local function data_stream_import(db, type)
	local db_old = data_stream_open('data2.db')

	local sql = "SELECT * FROM data"

	local stmt, err = db_old:prepare(sql)
	assert(stmt, err)

	local index = 0
	local lastTime = process.uptime()

	db:exec('begin;')

	for row in stmt:rows() do
		index = index + 1

		data_stream_add(db, row.type, row.value, row.timestamp)

		--print(index)
		local now = process.uptime()
		if (now - lastTime) > 1 then
			print('index: ' .. index)
			lastTime = now
		end
	end

	db:exec('commit;')

	stmt:close()
	db_old:close()

	print('total import: ' .. index)
end

-------------------------------------------------------------------------------
-- init

local function data_stream_init(db)
	if (isInited) then
		return
	end

	isInited = true

	if (not data_stream_exists(db, DATA_TABLE)) then
		local sql = "CREATE TABLE data (id INT, type INT, value TEXT, timestamp INT)"
		db:exec(sql)
	end

	if (not data_stream_exists(db, STAT_TABLE)) then
		local sql = "CREATE TABLE stat (id INT, type INT, method TEXT, range INT, value TEXT, timestamp INT, count INT)"
		db:exec(sql)
	end
end

function data_stream_latest(db, streamType) 
	streamType = data_stream_type(streamType)

	local sql = "SELECT id, type, value, timestamp, strftime('%Y-%m-%d %H:%M:%S', timestamp, 'unixepoch', 'localtime') as date FROM data"
	if (streamType) then
		sql = sql .. ' WHERE (type=?)'
	end

	sql = sql .. ' ORDER BY timestamp DESC'
	local stmt, err = db:prepare(sql)
	assert(stmt, err)

	if (streamType) then
		stmt:bind(streamType)
	end

	local ret = stmt:first_row()
	stmt:close()
	return ret
end

local function data_stream_list(db, streamType, limit)
	limit = limit or 20

	local sql = "SELECT id,type,value,timestamp FROM data"

	if (streamType) then
		sql = sql .. ' WHERE (type=?)'
	end
	
	streamType = data_stream_type(streamType)
	console.log('data_stream_list', sql, streamType)

	local stmt, err = db:prepare(sql)
	assert(stmt, err)

	if (streamType) then
		stmt:bind(streamType)
	end

	local ret = {}

	local index = 0
	for row in stmt:rows() do
		table.insert(ret, row)

		console.log(row)

		index = index + 1
		if (index > limit) then
			break
		end
	end

	stmt:close()

	return ret
end

local function data_stream_count(db, type, limit)
	local sql = "SELECT COUNT(*) FROM data"
	if (type) then
		sql = sql .. ' WHERE (type=?)'
	end
	
	local stmt, err = db:prepare(sql)
	assert(stmt, err)

	if (type) then
		stmt:bind(data_stream_type(type))
	end

	local ret = stmt:first_cols()
	stmt:close()
	return math.floor(ret)
end


-------------------------------------------------------------------------------
-- exports

-- name
-- mode
function exports.open(name)
	local db = data_stream_open(name)
	if (not db) then
		print('invalid database: ' .. tostring(name))
		return
	end

	db.import 	= data_stream_import
	db.latest 	= data_stream_latest
	db.list	 	= data_stream_list
	db.init 	= data_stream_init
	db.find 	= data_stream_find
	db.stat 	= data_stream_stat
	db.add 		= data_stream_add
	db.clear 	= data_stream_clear
	db.count 	= data_stream_count

	db.stat_list = data_stat_list
	db.stat_add  = data_stat_add

	return db
end

function exports.query(stream, mode, offset, options)
	local db = exports.open()
	if (not db) then 
		return
	end

    options = options or {}
    mode    = mode    or 'month'
    stream  = stream  or 'temperature'
    offset  = offset  or 0

    local chartData = db:stat('temperature', mode, offset)

	db:close()

    return { ret = 0, data = chartData }
end

return exports
