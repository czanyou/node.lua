local sqlite = require('sqlite3')
local utils  = require('utils')

console.log('sqlite', sqlite)

local cwd = process.cwd()
local filename = cwd .. '/test.db'
local db = sqlite.open(filename)
--console.log(db)

db:exec("DROP TABLE test")

local ret = db:exec("CREATE TABLE test (id INTEGER, name TEXT)")

local id = 111
local name = 'test'

local ret = db:exec("INSERT INTO test VALUES ("..id..", '"..name.."')")

db:exec("INSERT INTO test VALUES (2, 'Tina')")

name = 'TEST'
local ret = db:exec("UPDATE test SET name = '"..name.."' WHERE id = "..id)

local stmt = db:prepare("INSERT INTO test VALUES (?, ?)")
stmt:bind(15, "TT")
stmt:exec()


local stmt = db:prepare("INSERT INTO test VALUES (:id, :name)")
stmt:bind({id=18,name="HH"})
console.log('parameter_names', stmt:parameter_names())
stmt:exec()

local stmt = db:prepare("SELECT * FROM test")
--console.log('stmt', stmt)

console.log('column_count', 		stmt:column_count())
console.log('column_names', 		stmt:column_names())
console.log('column_decltypes', 	stmt:column_decltypes())


console.log('first_irow', 		stmt:first_irow())
console.log('first_row', 		stmt:first_row())
console.log('first_cols', 		stmt:first_cols())


for row in stmt:irows() do
	console.log(#row, row[1], row[2])
end

stmt:close()


db:close()

run_loop()

os.remove(filename)
