
# Sqlite3 数据库模块 Lua API

[TOC]

## 打开和关闭数据库

你可以打开一个文件数据库, 也可以打开一个内存数据库:

```lua
local sqlite3 = require('sqlite3')

-- Open a file database
db = sqlite3.open("filename")

-- Open a temporary database in memory
db = sqlite3.open_memory()

```

要关闭数据库只需要调用 close 方法即可:

```lua
db:close()

```

如果你关闭了数据库, 所有未提交的事务会回滚, 所有的资源会自动释放. 你不需要关闭和这个数据库相关的其他对象.

如果关闭数据库成功将返回这个数据库对象本身.

如果发生错误则返回 nil 值和错误信息.

## 执行 SQL 语句

如果要执行的 SQL 语句不会返回记录, 可以直接调用 db:exec() 方法:

```lua
db:exec( "CREATE TABLE test (id, data)" )
db:exec[[ INSERT INTO test VALUES (1, "Hello World") ]]

```

你也可以在一个 exec 方法中执行多条 SQL 语句.

```lua
db:exec[[
  BEGIN TRANSACTION;
    CREATE TABLE test (id, data);
      INSERT INTO test VALUES (1, "Hello World");
      INSERT INTO test VALUES (2, "Hello Lua");
      INSERT INTO test VALUES (3, "Hello Sqlite3");
  END TRANSACTION
]]
```

## 使用 SELECT 语句查询数据记录

不能使用 db:exec() 方法来执行 SELECT 语句.

将使用迭代器的方式来返回数据记录, 非常类似于 ipairs() or pairs() 

```lua
-- Returns a row as an integer indexed array
for row in db:irows("SELECT * FROM test") do
  print(row[1], row[2])
end

-- Returns a row as an table, indexed by column names
for row in db:rows("SELECT * FROM test") do
  print(row.id, row.data)
end

-- Returns each column directly
for id, data in db:cols("SELECT * FROM test") do
  print(id, data)
end
```

## 获取单独的一行

有时间只需要得到查询到的第一行记录, 则可以使用如下的方法:

```lua
row = db:first_irow("SELECT count(*) FROM test")
print(row[1])

row = db:first_row("SELECT count(*) AS count FROM test")
print(row.count)

count = db:first_cols("SELECT count(*) FROM test")
print(count)

```

## 简单的预备查询语句

通过 db:prepare() 方法可以创建和返回预备查询语句

```lua
stmt = db:prepare("SELECT * FROM test")
```

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
以及:

```lua
stmt = db:prepare("SELECT count(*) AS count FROM test")

row = stmt:first_irow()
print(row[1])

row = stmt:first_row()
print(row.count)

count = stmt:first_cols()
print(count)
```

你还可以编译多条 SQL 语句:

```lua

stmt = db:prepare[[
    INSERT INTO test VALUES (1, "Hello World");
    INSERT INTO test VALUES (2, "Hello Lua");
    INSERT INTO test VALUES (3, "Hello Sqlite3")
]]

stmt:exec()

```

## 使用参数绑定的预备查询语句

### 使用匿名参数:

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

### 使用有名称的参数

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

### 使用 '名称:值' 表格来绑定参数

```lua
...

stmt = db:prepare[[
    BEGIN TRANSACTION;
    INSERT INTO person_name VALUES (:id, :name);
    INSERT INTO person_email VALUES (:id, :email);
    INSERT INTO person_address VALUES (:id, :address);
    COMMIT
]]

function insert(id, name, address, email)
    args = { }
    args.id = id
    args.name = name
    args.address = address
    args.email = args.email
    stmt:bind(args)
    stmt:exec()
end

-- A shorter version equal to the above
function insert2(id, name, address, email)
    stmt:bind{ id=id, name=name, address=address, email=email}
    stmt:exec()
end

...

```


### 查询参数名称

你可以用 stmt:parameter_names() 方法查询已编译的语句可以用参数, 这个方法会返回一个数组.
这个数组中的方法名中不包含参数前面的 '$' 或 ':' 符号.

比如:

```lua
...

stmt = db:prepare[[
  BEGIN TRANSACTION;
    INSERT INTO person_name VALUES (:id, :name);
    INSERT INTO person_email VALUES (:id, :email);
    INSERT INTO person_address VALUES (:id, :address);
  COMMIT
]]

names = stmt:parameter_names()

print( #names )                 -- "4"
print( names[1] )               -- "id"
print( names[2] )               -- "name"
print( names[3] )               -- "email"
print( names[4] )               -- "address"

...

```

## 定义用户方法 

你可以在 Sqlite3 中定义用户函数. 用户函数可以在 SQL 语言中调用, 由 Sqlite3 解析执行并返回结果.

你可以定义一些用于计算数值之类的方法.

要使用用户函数, 你必须提交用户函数的名称, 用户函数接收的参数个数, 以及用户函数本身.

比如:

```lua
function sql_add_ten(a)
  return a + 10
end

db:set_function("add_ten", 1, sql_add_ten)

for id, add_ten, data in db::rows("SELECT id, add_ten(id), data FROM test") do
  print(id, add_ten, data)
end

```

你也可以定义参数个数可变的用户函数, 在使用 set_function 方法时, 将参数个数设为 -1 即可. 

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
