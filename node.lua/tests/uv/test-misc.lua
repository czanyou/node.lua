local tap = require("ext/tap")
local test = tap.test

test(
	"uv.guess_handle",
	function(print, p, expect, uv)
		local types = {
			assert(uv.guess_handle(0)),
			assert(uv.guess_handle(1)),
			assert(uv.guess_handle(2))
		}
		p("stdio fd types: ", table.unpack(types))
	end
)

test(
	"uv.version and uv.version_string",
	function(print, p, expect, uv)
		local version = assert(uv.version())
		local version_string = assert(uv.version_string())
		p {code = version, version = version_string}
		assert(type(version) == "number")
		assert(type(version_string) == "string")
	end
)

test(
	"memory size",
	function(print, p, expect, uv)
		local rss = uv.resident_set_memory()
		local total = uv.get_total_memory()
		local free = uv.get_free_memory()

		assert(rss < total)

		p("memory.size: rss/free/total: ", rss, free, total)
	end
)

test(
	"uv.uptime",
	function(print, p, expect, uv)
		local uptime = assert(uv.uptime())
		p {"uv.uptime:", uptime}
	end
)

test(
	"uv.getrusage",
	function(print, p, expect, uv)
		local rusage = assert(uv.getrusage())
		p("rusage.maxrss:", rusage.maxrss)
	end
)

test(
	"uv.cpu_info",
	function(print, p, expect, uv)
		local info = assert(uv.cpu_info())
		p("CPU core count: ", #info)
		assert(#info > 0)
	end
)

test(
	"uv.interface_addresses",
	function(print, p, expect, uv)
		local addresses = assert(uv.interface_addresses())
		for name, info in pairs(addresses) do
			--p('interface', name, addresses[name])
			p("interface", name)
			--p('info', info)
		end
	end
)

test(
	"uv.loadavg",
	function(print, p, expect, uv)
		local avg = {assert(uv.loadavg())}
		p("loadavg", avg[1], avg[2], avg[3])
		assert(#avg == 3)
	end
)

test(
	"uv.exepath",
	function(print, p, expect, uv)
		local path = assert(uv.exepath())
		p("exepath", path)
	end
)

test(
	"uv.os_homedir",
	function(print, p, expect, uv)
		local path = assert(uv.os_homedir())
		p("os_homedir", path)
	end
)

test(
	"uv.os_tmpdir",
	function(print, p, expect, uv)
		local path = assert(uv.os_tmpdir())
		p("os_tmpdir", path)
	end
)

test(
	"uv.os_gethostname",
	function(print, p, expect, uv)
		local path = assert(uv.os_gethostname())
		p("os_gethostname", path)
	end
)

test(
	"uv.os_getenv",
	function(print, p, expect, uv)
		local path = assert(uv.os_getenv("PATH"))
		p("os_getenv", path)
	end
)

test(
	"uv.os_setenv",
	function(print, p, expect, uv)
		uv.os_setenv("TEST", "TEST")
		local path = assert(uv.os_getenv("TEST"))
		p("os_setenv", path)
	end
)

test(
	"uv.os_unsetenv",
	function(print, p, expect, uv)
		uv.os_unsetenv("TEST")
		local path = uv.os_getenv("TEST")
		p("os_unsetenv", path)
	end
)

test(
	"uv.cwd and uv.chdir",
	function(print, p, expect, uv)
		local old = assert(uv.cwd())
		--p('old chdir', old)
		assert(uv.chdir("/"))
		local cwd = assert(uv.cwd())
		p("new chdir", cwd)
		assert(cwd ~= old)
		assert(uv.chdir(old))
	end
)

test(
	"uv.hrtime",
	function(print, p, expect, uv)
		local time = assert(uv.hrtime())
		p("hrtime", time)
	end
)

test(
	"test_getpid",
	function(print, p, expect, uv)
		assert(uv.getpid())
	end
)

tap.run()
