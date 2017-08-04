# 数据库 (sqlite3)

[TOC]

通过 require('sqlite3') 调用.

## sqlite3.open

    sqlite3.open(filename)

返回指定名称的文件数据库

- filename {String} 数据库文件名

```lua
-- Open a file database
db = sqlite3.open("filename")

db:close()

```


## sqlite3.open_memory

    sqlite3.open_memory()

打开一个内存数据库

```lua
-- Open a temporary database in memory
db = sqlite3.open_memory()

db:close()

```


## 类 sqlite3Database

只能通过 sqlite3.open 创建并返回这个类的实例


### db:close

    db:close()

关闭这个数据库


### db:interrupt

    db:interrupt()



### db:last_insert_rowid

    db:last_insert_rowid()

返回最后插入的 rowid


### db:changes

    db:changes()

返回最后改变的行数


### db:total_changes

    db:total_changes()

返回总共改变的行数


### db:exec

    db:exec(sql)

直接执行指定 SQL 语句, 一般用来执行 UPDATE 等 SQL 语句

```lua
db:exec( "CREATE TABLE test (id, data)" )
db:exec[[ INSERT INTO test VALUES (1, "Hello World") ]]
```

### db:irows

    db:irows(sql, tab)

执行指定 SQL 语句并返回所有行, 返回的记录为数据

```lua
-- Returns a row as an integer indexed array
for row in db:irows("SELECT * FROM test") do
  print(row[1], row[2])
end

```

### db:rows

    db:rows(sql, tab)

执行指定 SQL 语句并返回所有行, 返回的记录为表格

```lua
-- Returns a row as an table, indexed by column names
for row in db:rows("SELECT * FROM test") do
  print(row.id, row.data)
end

```


### db:cols

    db:first_cols(sql)

```lua
-- Returns each column directly
for id, data in db:cols("SELECT * FROM test") do
  print(id, data)
end

```


### db:first_irow

    db:first_irow(sql, tab)

执行指定 SQL 语句并返回第一行, 返回的记录为数据

```lua
row = db:first_irow("SELECT count(*) FROM test")
print(row[1])
```


### db:first_row

    db:first_row(sql, tab)

执行指定 SQL 语句并返回第一行, 返回的记录为表格

```lua
row = db:first_row("SELECT count(*) AS count FROM test")
print(row.count)
```


### db:first_cols

    db:first_cols(sql)

```lua
count = db:first_cols("SELECT count(*) FROM test")
print(count)
```


### db:prepare

    db:prepare(paranames, sql)

预备执行指定 SQL 语句

- sql 要执行的 SQL 语句, 可以带参数, 如 `SELECT * FROM data WHERE id=?`

返回 sqlite3Stmt 类对象

```lua
stmt = db:prepare("SELECT * FROM test")

for row in stmt:irows() do
  print(row[1], row[2])
end

for row in stmt:rows() do
  print(row.id, row.data)
end

for id, data in stmt:cols() do
  print(id, data)
end
```

You could even compile multiple SQL statements:

```lua

stmt = db:prepare[[
    INSERT INTO test VALUES (1, "Hello World");
    INSERT INTO test VALUES (2, "Hello Lua");
    INSERT INTO test VALUES (3, "Hello Sqlite3")
]]

stmt:exec()
```

Anonymous Parameters:

```lua
insert_stmt = db:prepare[[
  INSERT INTO test VALUES (?, ?);
  INSERT INTO test VALUES (?, ?)
]]

function insert(id1, data1, id2, data2)
  insert_stmt:bind(id1, data1, id2, data2)
  insert_stmt:exec()
end

insert( 1, "Hello World",   2, "Hello Lua" )
insert( 3, "Hello Sqlite3", 4, "Hello User" )

get_stmt = db:prepare("SELECT data FROM test WHERE test.id = ?")

function get_data(id)
  get_stmt:bind(id)
  return get_stmt:first_cols()
end

print( get_data(1) )
print( get_data(2) )
print( get_data(3) )
print( get_data(4) )
```

Named Parameters:

```lua
db:exec("CREATE TABLE person_name (id, name)")
db:exec("CREATE TABLE person_email (id, email)")
db:exec("CREATE TABLE person_address (id, address)")

-- '$' and ':' are optional
parameter_names = { ":id", "$name", "address", "email" }

stmt = db:prepare(parameter_names, [[
  BEGIN TRANSACTION;
    INSERT INTO person_name VALUES (:id, :name);
    INSERT INTO person_email VALUES (:id, :email);
    INSERT INTO person_address VALUES (:id, :address);
  COMMIT
]])

function insert(id, name, address, email)
  stmt:bind(id, name, address, email)
  stmt:exec()
end

insert( 1, "Michael", "Germany", "mroth@nessie.de" )
insert( 2, "John",    "USA",     "john@usa.org" )
insert( 3, "Hans",    "France",  "hans@france.com" )
```



### db:set_function

    db:set_function(name, num_args, func)

定义用户方法

- name {String} 用户方法的名称
- num_args {Number} 方法参数数量
- func {Function} 这个方法本身

```lua
function sql_add_ten(a)
  return a + 10
end

db:set_function("add_ten", 1, sql_add_ten)

for id, add_ten, data in db::rows("SELECT id, add_ten(id), data FROM test") do
  print(id, add_ten, data)
end
```

使用可变数量参数:

```lua
function my_max(...)
  local result = 0
  for _, value in ipairs(arg) do
    result = math.max(result, value)
  end
  return result
end

db:set_function("my_max", -1, my_max)

max1 = db:first_cols("SELECT my_max(17, 7)")
max2 = db:first_cols("SELECT my_max(1, 2, 3, 4, 5)")

print(max1, max2)       -- 17     5
```


### db:set_aggregate

    db:set_aggregate(name, num_args, create_funcs)

定义 aggregate 方法

- name {String} 方法的名称
- num_args {Number} 方法参数数量
- func {Function} 这个方法本身

```lua
db:exec[[
  CREATE TABLE numbers (num1, num2);
  INSERT INTO numbers VALUES(1, 2);
  INSERT INTO numbers VALUES(3, 4);
  INSERT INTO numbers VALUES(5, 6);
]]

function my_product_sum_aggregate()
  local product_sum = 0

  local function step(a, b)
    local product = a * b
    product_sum = product_sum + product
  end

  local function final(num_called)
    return product_sum / num_called
  end

  return step, final
end

db:set_aggregate("product_sum", 2, my_product_sum_aggregate)

print( db:first_cols("SELECT product_sum(num1, num2) FROM numbers") )
```


### db:set_trace_handler

    db:set_trace_handler(func)

设置根踪处理函数, 可以打印所有执行的 SQL 语句

- func {Function} 处理方法

```lua
function mytrace(sql_string)
  print("Sqlite3:", sql_string)
end

db:set_trace_handler(mytrace)
```


### db:set_busy_timeout

    db:set_busy_timeout(ms)

- ms {Number} 毫秒

设置处理超时时间

```lua
-- Open the database
db = sqlite3.open("filename")

-- Set 2 seconds busy timeout
db:set_busy_timeout(2 * 1000)

-- Use the database
db:exec(...)
```


### db:set_busy_handler

    db:set_busy_handler(func)

- func {Funtion} 超时处理方法

设置超时处理方法

```lua
-- Open the database
db = sqlite3.open("filename")

-- Ten attempts are made to proceed, if the database is locked
function my_busy_handler(attempts_made)
  if attempts_made < 10 then
    return true
  else
    return false
  end
end

-- Set the new busy handler
db:set_busy_handler(my_busy_handler)

-- Use the database
db:exec(...)
```



## 类 sqlite3Statement

只能通过 db:prepare 创建并返回这个类的实例


### stmt:bind

    stmt:bind(...)

绑定查询参数, 参数顺序和 SQL 语句中参数顺序及个数一致

如果 SQL 语句中的参数都是有名称的, 也可以通过传一个对象来绑定参数
 
如: 

```lua
local sql = "SELECT * FORM data WHERE id=? AND name=?"

local stmt = db:prepare()
stmt:bind(100, "lucy")
local rows = stmt:rows()
console.log(rows())

---

local sql = "SELECT * FORM data WHERE id=:id AND name=:name"

local stmt = db:prepare()
stmt:bind({id=100, name="lucy"})
local rows = stmt:rows()
console.log(rows())

```

### stmt:reset

    stmt:reset()

复位这个对象


### stmt:close

    stmt:close()

关闭这个对象


### stmt:column_count

    stmt:column_count()

返回总共列数


### stmt:column_decltypes

    stmt:column_decltypes()

返回包含所有列数据类型名的数组


### stmt:column_names

    stmt:column_names()

返回包含所有列名的数组


### stmt:exec

    stmt:exec()

执行这个对象


### stmt:parameter_names

    stmt:parameter_names()

返回包含所有参数名的数组


### stmt:cols

    stmt:cols(autoclose)

返回结果, 返回的格式为多个返回值

- autoclose {Boolean} 是否自动关闭这个对象


### stmt:irows

    stmt:irows(tab, autoclose)

返回结果, 返回的格式为数组

- tab {Table}
- autoclose {Boolean} 是否自动关闭这个对象


### stmt:rows

    stmt:rows(tab, autoclose)

返回结果, 返回的格式为对象

- tab {Table}
- autoclose {Boolean} 是否自动关闭这个对象


### stmt:first_cols

    stmt:first_cols(autoclose)

返回第一行结果, 返回的格式为多个返回值

- autoclose {Boolean} 是否自动关闭这个对象


### stmt:first_irow

    stmt:first_irow(tab, autoclose)

返回第一行结果, 返回的格式为数组

- tab {Table}
- autoclose {Boolean} 是否自动关闭这个对象


### stmt:first_row

    stmt:first_row(tab, autoclose)

返回第一行结果, 返回的格式为对象

- tab {Table}
- autoclose {Boolean} 是否自动关闭这个对象




