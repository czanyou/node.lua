local tap 	    = require("ext/tap")
local utils     = require('utils')
local path      = require('path')
local assert    = require('assert')
local Buffer    = require('buffer').Buffer
local sqlite3   = require('sqlite3')

local function open_data(name)
    local filename = path.join(os.tmpdir, name or 'data.db')
    print(filename)

    os.remove(filename)

    return sqlite3.open(filename)
end

tap(function(test)
    test("open_data", function()
    	local db = open_data()

        --console.log(db)

        db:exec("DROP TABLE test")
        db:exec("CREATE TABLE test (id INTEGER, name TEXT)")

        db:set_trace_handler(function(...)
            console.log(...)
        end)

        db:set_busy_handler(function(...)
            console.log(...)
        end)

        print('last_insert_rowid',  db:last_insert_rowid())
        print('changes',            db:changes())
        print('total_changes',      db:total_changes())
 
        db:exec("INSERT INTO test VALUES (2, 'Tina')")
        db:exec("INSERT INTO test VALUES (2, 'Tina')")
        db:exec("INSERT INTO test VALUES (2, 'Tina')")

        print('last_insert_rowid',  db:last_insert_rowid())
        print('changes',            db:changes())
        print('total_changes',      db:total_changes())
        
        db:close()
    end)

    test("open_data", function()
        local db = open_data('data2.db')

        db:exec("DROP TABLE test")
        db:exec("CREATE TABLE test (id INTEGER, name TEXT)")
        db:exec("INSERT INTO test VALUES (2, 'Tina')")
        db:exec("INSERT INTO test VALUES (3, 'Tina')")
        db:exec("INSERT INTO test VALUES (4, 'Tina')")
       
        --console.log(db)

        local ret = db:rows('SELECT * FROM test')
        console.log(ret())
        console.log(ret())
        console.log(ret())
        console.log(ret())
    end)

    test("open_data", function()
        local db = open_data('data3.db')

        db:exec("DROP TABLE test")
        db:exec("CREATE TABLE test (id INTEGER, name TEXT)")
        db:exec("INSERT INTO test VALUES (2, 'Tina')")
        db:exec("INSERT INTO test VALUES (3, 'Tina')")
        db:exec("INSERT INTO test VALUES (4, 'Tina')")
       
        local ret = db:irows('SELECT * FROM test')
        console.log(ret())
        console.log(ret())
        console.log(ret())
        console.log(ret())
    end)

    test("open_data", function()
        local db = open_data('data4.db')

        db:exec("DROP TABLE test")
        db:exec("CREATE TABLE test (id INTEGER, name TEXT)")
        db:exec("INSERT INTO test VALUES (2, 'Tina')")
        db:exec("INSERT INTO test VALUES (3, 'Tina')")
        db:exec("INSERT INTO test VALUES (4, 'Tina')")
       
        local ret = db:cols('SELECT * FROM test')
        console.log(ret())
        console.log(ret())
        console.log(ret())
        console.log(ret())
    end)

    test("open_data", function()
        local db = open_data('data4.db')

        db:exec("DROP TABLE test")
        db:exec("CREATE TABLE test (id INTEGER, name TEXT)")
        db:exec("INSERT INTO test VALUES (2, 'Tina')")
        db:exec("INSERT INTO test VALUES (3, 'Tina')")
        db:exec("INSERT INTO test VALUES (4, 'Tina')")
       
        local ret = db:prepare('SELECT * FROM test WHERE id > ?')
        ret:bind(2)

        console.log('column_count', ret:column_count())
        console.log('column_decltypes', ret:column_decltypes())
        console.log('column_names', ret:column_names())
        console.log('parameter_names', ret:parameter_names())

        local rows = ret:rows()
        console.log(rows())
    end)

    test("open_data", function()
        local db = open_data('data4.db')

        db:exec("DROP TABLE test")
        db:exec("CREATE TABLE test (id INTEGER, name TEXT)")
        db:exec("INSERT INTO test VALUES (2, 'Tina')")
        db:exec("INSERT INTO test VALUES (3, 'Tina')")
        db:exec("INSERT INTO test VALUES (4, 'Tina')")
       
        local ret = db:prepare('SELECT * FROM test WHERE id > :id')
        ret:bind({id=2})

        console.log('column_count', ret:column_count())
        console.log('column_decltypes', ret:column_decltypes())
        console.log('column_names', ret:column_names())
        console.log('parameter_names', ret:parameter_names())

        local rows = ret:rows()
        console.log(rows())
    end)

   
end)

