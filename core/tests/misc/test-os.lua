local tap = require("ext/tap")
local test = tap.test

test("Test os", function()
	print("arch():   ", os.arch())
	print("clock():  ", os.clock())
	print("cpus():   ", os.cpus())
	print("date():   ", os.date())

	print("freemem():", os.freemem())
	print("homedir():", os.homedir())
	print("loadavg():", os.loadavg())
	print("networkInterfaces():", os.networkInterfaces())
	print("platform()", os.platform())
	print("time():   ", os.time())

	print("tmpdir: ", os.tmpdir)
	print("tmpname():", os.tmpname())
	print("hostname():", os.hostname())
	print("totalmem()", os.totalmem())
	print("type():   ", os.type())
	print("uptime(): ", os.uptime())

	print("getpid(): ", os.getpid())
	print("getppid(): ", os.getppid())

	print("ifid(1): ", os.ifid(1))
	print("ifname(1): ", os.ifname(1))

	print("ifid(0): ", os.ifid(0))
	print("ifname(0): ", os.ifname(0))

	print("gettimeofday(): ", os.gettimeofday())
	console.log("uname(): ", os.uname())
	print("getpriority(pid): ", os.getpriority(os.getpid()))

	if (os.printAllHandles) then
		print("printAllHandles(): ", os.printAllHandles())
		print("printActiveHandles(): ", os.printActiveHandles())
	end

	print("title:  ", process.title)
	print("PATH:   ", os.getenv("PATH"))
	console.log("EOL:", os.EOL)
	
	os.setenv("TEST", "Bar")
	print("set TEST:   ", os.getenv("TEST"))

	os.unsetenv("TEST")
	print("unset TEST:   ", os.getenv("TEST"))

	-- console.log(os)
end)

test("Test Date", function()
	local now = Date.now();
	print('now()', now);

	now = Date.now();
	print('now()', now);

	now = Date.now();
	print('now()', now);

	local date = Date:new(1556432676482)
	console.log(date)
	console.log(Date)

	print('date:getTime()', date:getTime());

	print('date:getDay()', date:getDay());
	print('date:getDate()', date:getDate());
	print('date:getMonth()', date:getMonth());
	print('date:getYear()', date:getYear());

	print('date:getHours()', date:getHours());
	print('date:getMinutes()', date:getMinutes());
	print('date:getSeconds()', date:getSeconds());
	print('date:getMilliseconds()', date:getMilliseconds());

	date:setTime(1556432676482 + 3600 * 1000)
	print('date:getTime()', date:getTime());
	print('date:toString()', date:toString());

	date:setDate(29)
	date:setMonth(5)
	date:setYear(2020)
	print('date:getTime()', date:getTime());
	print('date:toString()', date:toString());

	date:setHours(19)
	date:setMinutes(55)
	date:setSeconds(33)
	print('date:getTime()', date:getTime());
	print('date:toString()', date:toString());

	date:setMonth(13)
	date:setSeconds(63)
	date:setMilliseconds(88)
	print('date:getTime()', date:getTime());
	print('date:toString()', date:toString());
	print('date:toISOString()', date:toISOString());
	print('date:toDateString()', date:toDateString());
	print('date:toTimeString()', date:toTimeString());
end)

tap.run()
