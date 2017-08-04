require("ext/tap")(function (test)

test("Test os", function ()

print('arch:   ', os.arch())
print('clock:  ', os.clock())
print('cpus:   ', os.cpus())
print('date:   ', os.date())

--print('endianness:   ', os.endianness())

--print(os.difftime())
-- print(os.endianness())

print('freemem:', os.freemem())
print('homedir:', os.homedir())
print('loadavg:', os.loadavg())
print('network:', os.networkInterfaces())
print('platform', os.platform())
print('release:', os.release)
print('time:   ', os.time())

print('tmpdir: ', os.tmpdir)
print('tmpname:', os.tmpname())
print('hostname:', os.hostname())
print('totalmem', os.totalmem())
print('type:   ', os.type())
print('uptime: ', os.uptime())

print('title:  ', process.title)
print('PATH:   ', os.getenv('PATH'))
print('EOL:   [', os.EOL, ']')

os.setenv("TEST", "Bar")
print('set TEST:   ', os.getenv('TEST'))

os.unsetenv("TEST")
print('unset TEST:   ', os.getenv('TEST'))

end)

end)