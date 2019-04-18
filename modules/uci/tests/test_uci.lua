local uci = require('luci')
console.log(uci)

--console.log(uci.set_confdir('/tmp/config'))

x = uci.cursor()

console.log(x)

x:foreach("foo",nil,function(...)
    console.log(...)
end) 

console.log('first.name', x:get("foo", "first", "name"))
console.log('third.name', x:get("foo", "third", "name"))

console.log(x:set('foo', 'first', 'title', 'VP')) 

--console.log(uci.load('network'))
--console.log(x:add("foo", "test", "cc"))
console.log('delete @test[0]', x:delete('foo', '@test[0]'))
console.log('delete third', x:delete('foo', 'third'))

console.log(x:set('foo', 'bar', 'for')) 
console.log(x:set('foo', 'bar', 'a', 'b'))

console.log('changes', x:changes('foo'))
console.log('commit', x:commit('foo'))

console.log('get_confdir', uci.get_confdir())
console.log('get_savedir', uci.get_savedir())
console.log('list_configs', uci.list_configs())
