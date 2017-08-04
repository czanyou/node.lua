local utils = require('utils')

require('ext/tap')(function(test)
	
  	test('string', function(expect)

		local data = ' \tab cd ef gh 1234 56\r\n '

		assert(data:find('cd') == 6)
		assert(data:find('12345') == nil)

		assert(data:length() == 24)
		assert(#data:split(' ') == 8)
		assert(#data:split(',') == 1)
		assert(#data:split() == 8)
		assert(data:trim() == 'ab cd ef gh 1234 56')

		assert(data:startsWith(' \tab'))
		assert(not data:startsWith(' \tabc'))
		assert(not data:endsWith(' \tab'))
		assert(data:endsWith('\r\n '))


		local data2 = ' \t  \r\n '
		--console.log('data2', data2:trim())
		assert(data2:trim() == '')

		--local script = string.dump(console.log)
		--console.log(script)
  	end)

end)


-- lnode test-string.lua