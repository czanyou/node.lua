local lutils = require('lutils')
local assert = require('assert')
local fs = require('fs')
local thread = require('thread')

local tap = require('ext/tap')
local test = tap.test

test('lutils.hex_encode', function()
    local data = "888888"
    local hash = lutils.hex_encode(data)
    assert.equal(hash, '383838383838')
    
    local raw = lutils.hex_decode(hash)
    assert.equal(raw, '888888')
    
    assert.equal(lutils.hex_decode(''), nil)
    assert.equal(lutils.hex_encode(''), nil)
    
    local data = "\11\10\78\119\232\82\135\107"
    local hash = lutils.hex_encode(data)
    --assert.equal(hash, '383838383838')
    print('hash', hash)
end)


test('lutils.md5', function()
    local data = "888888"
    local hash = lutils.md5(data)
    
    local hex_hash = lutils.hex_encode(hash)
    assert.equal(hex_hash, '21218cca77804d2ba1922c33e0151105')

--utils.printBuffer(hash)
end)

test('lutils.base64_encode', function()
    assert.equal(lutils.base64_encode(''), nil)
    assert.equal(lutils.base64_encode('A'), 'QQ==')
    assert.equal(lutils.base64_encode('AB'), 'QUI=')
    assert.equal(lutils.base64_encode('ABC'), 'QUJD')
    assert.equal(lutils.base64_encode('888888'), 'ODg4ODg4')

end)

test('lutils.base64_decode', function()
    assert.equal(lutils.base64_decode(''), nil)
    assert.equal(lutils.base64_decode('QQ=='), 'A')
    assert.equal(lutils.base64_decode('QUI='), 'AB')
    assert.equal(lutils.base64_decode('QUJD'), 'ABC')
    assert.equal(lutils.base64_decode('ODg4ODg4'), '888888')

end)

test('lutils.base64_decode', function()
    console.log('os_arch', lutils.os_arch())
    console.log('os_platform', lutils.os_platform())
    console.log('os_statfs', lutils.os_statfs('/'))
    console.log('os_arch', lutils.os_arch())


end)


test('lutils.os_file_lock', function()
    local filename = '/tmp/lock'
    
    local fd1 = fs.openSync(filename, 'w+')
    print('fd1', fd1)
    
    if (not fd1) then
        return
    end
    
    local ret = lutils.os_file_lock(fd1, 'w')
    print('write1', ret)
    
    if (ret >= 0) then
        thread.sleep(1000 * 5)
        
        ret = lutils.os_file_lock(fd1, 'u')
        print('unlock', ret)
    end
end)

tap.run()
