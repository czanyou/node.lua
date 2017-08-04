/**
 *  Copyright 2016 The Node.lua Authors. All Rights Reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */
#include "lnode.h"

/** Prints the current lnode version information. */
static void lnode_print_version(int flags) {
  	char buffer[PATH_MAX];
  	memset(buffer, 0, sizeof(buffer));
  	sprintf(buffer, "v%d.%d (Lua %s.%s.%s, libuv %s, build %s %s)", 
  		LNODE_MAJOR_VERSION, LNODE_MINOR_VERSION,
  		LUA_VERSION_MAJOR, LUA_VERSION_MINOR, LUA_VERSION_RELEASE, 
  		uv_version_string(), __DATE__, __TIME__);
  	lua_writestring(buffer, strlen(buffer));
  	lua_writeline();

  	sprintf(buffer, "\n"
	  	"usage: lnode [options] [ -e script | script.lua [arguments]]\n"
	  	"\n"
  		"options:\n"
		"\n"
  		"  -d  run as daemon\n"
  		"  -e  evaluate script\n"
  		"  -l  print path information\n"
  		"  -p  evaluate script and print result	\n"
  		"  -r  module to preload\n"
  		"  -v  print Node.lua version\n"
  		"  -   load script from stdin\n"
		"\n"
		);

	if (flags & 0x01) {
		lua_writestring(buffer, strlen(buffer));
		lua_writeline();
	}
}

static int lnode_print_info(lua_State* L) {
  char script[] = 
    "pcall(require, 'init')\n"
    "local lnode = require('lnode')\n"
    "print('NODE_LUA_ROOT:\\n' .. lnode.NODE_LUA_ROOT .. '\\n')\n"
    "local path = string.gsub(package.path, ';', '\\n')"
  	"print('package.path:\\n' .. path)\n"
    "local cpath = string.gsub(package.cpath, ';', '\\n')"
  	"print('package.cpath:\\n' .. cpath)\n"
  	;

  return lnode_call_script(L, script, "info.lua");
}

/**
 * Note that a Lua virtual machine can only be run in a single thread, 
 * creating a new virtual machine for each new thread created.
 * This method runs at the beginning of each thread to create new Lua 
 * virtual machines and register the associated built-in modules.
 */
static lua_State* lnode_vm_acquire() {
	lua_State* L = luaL_newstate();
	if (L == NULL) {
		return L;
	}

	luaL_openlibs(L);	// Add in the lua standard libraries
	lnode_openlibs(L);	// Add in the lnode lua ext libraries
	lnode_init(L);

	return L;
}

/**
 * Call this method at the end of each thread to close the relevant Lua 
 * virtual machine and release the associated resources.
 */
static void lnode_vm_release(lua_State* L) {
  	lua_close(L);
}

int main(int argc, char* argv[]) {
	lua_State* L 	= NULL;
	int index 		= 0;
	int res 		= 0;
	int script 		= 1;
	int has_eval	= 0;
	int has_info	= 0;
	int has_print	= 0;
	int has_script 	= 0;
	int has_require	= 0;

#ifndef _WIN32
	signal(SIGPIPE, SIG_IGN);	// 13) 管道破裂: Write a pipe that does not have a read port

#endif
	
	// Hooks in libuv that need to be done in main.
	argv = uv_setup_args(argc, argv);

	if (argc >= 2) {
		const char* option = argv[1];

		if (strcmp(option, "-d") == 0) {
			// Runs the current script in the background
			lnode_run_as_deamon();
			script = 2;

		} else if (strcmp(option, "-l") == 0) {
			has_info = 1;

		} else if (strcmp(option, "-e") == 0) {
			script = 2;
			has_eval = 1;

		} else if (strcmp(option, "-p") == 0) {
			script = 2;
			has_print = 1;

		} else if (strcmp(option, "-r") == 0) {
			script = 2;
			has_require = 1;

		} else if (strcmp(option, "-v") == 0) {
			lnode_print_version(0);
			return 0;		

		} else if (strcmp(option, "-") == 0) {
			// Read Lua script content from the pipeline
			script = 2;
			has_script = 1;

		} else if (option[0] == '-') {
			script = 2;
		}
	}

	// filename
	const char* filename = NULL;
	if ((script > 0) && (script < argc)) {
		filename = argv[script];
		has_script = 1;
	}

	char realname[PATH_MAX];
	memset(realname, 0, PATH_MAX);

	// Create the lua state.
	L = luaL_newstate();
	if (L == NULL) {
		fprintf(stderr, "luaL_newstate has failed\n");
		return 1;
	}

	luaL_openlibs(L);  	// Add in the lua standard libraries
	lnode_openlibs(L); 	// Add in the lua ext libraries
	lnode_create_arg_table(L, argv, argc, script);

	luv_set_thread_cb(lnode_vm_acquire, lnode_vm_release);
	lnode_init(L);

	if (has_info) {
		lnode_print_info(L);

	} else if (has_eval) {
		if (filename) {
			lnode_call_script(L, "pcall(require, 'init')\n", "init");
			res = lnode_call_script(L, filename, "eval.lua");
		}

	} else if (has_print) {
		if (filename) {
			snprintf(realname, PATH_MAX, "print(%s)", filename);

			lnode_call_script(L, "pcall(require, 'init')\n", "init");
			res = lnode_call_script(L, realname, "print.lua");
		}
		
	} else if (has_require) {
		if (filename) {
			snprintf(realname, PATH_MAX, "require('%s')", filename);

			lnode_call_script(L, "pcall(require, 'init')\n", "init");
			res = lnode_call_script(L, realname, "require.lua");
		}

	} else if (has_script) {
		lnode_init(L);

		filename = lnode_get_realpath(filename, realname);
		if (filename) {
			const char* fmt = 
				"pcall(require, 'init')\n"
				"dofile('%s')\n"
				//"local fn = loadfile('%s')\n"
				//"if (fn) then fn(...) end\n"
				"pcall(run_loop)\n"
				"process:emit('exit')\n";
			int length = strlen(fmt) + strlen(filename) + 32;
			char* buffer = malloc(length);
			snprintf(buffer, length, fmt, filename);
			res = lnode_call_script(L, buffer, filename);
			free(buffer);
			buffer = NULL;

		} else { // load stdio 
			const char* buffer = 
				"pcall(require, 'init')\n"
				"dofile()\n"
				//"local fn = loadfile()\n"
				//"if (fn) then fn(...) end\n"
				"pcall(run_loop)\n"
				"process:emit('exit')\n";
			res = lnode_call_script(L, buffer, "main.lua");
		}

		// res = lnode_call_file(L, filename);
		// printf("ret=%d\r\n", res);

	} else {
		lnode_print_version(1);
	}

	lnode_vm_release(L);
	return res;
}
