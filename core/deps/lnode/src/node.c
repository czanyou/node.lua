/**
 *  Copyright 2016-2020 The Node.lua Authors. All Rights Reserved.
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

#if !defined(LUA_INIT_VAR)
#define LUA_INIT_VAR "LUA_INIT"
#endif

extern const uint8_t init_data[];

#define LUA_INITVARVERSION LUA_INIT_VAR LUA_VERSUFFIX

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
	lnode_init_package_paths(L);

	return L;
}

#if !defined(LUA_PROGNAME)
#define LUA_PROGNAME		"lua"
#endif

static const char *progname = LUA_PROGNAME;

static lua_State *globalL = NULL;

/*
** Prints an error message, adding the program name in front of it
** (if present)
*/
static void lnode_print_message (const char *pname, const char *msg) {
  	if (pname) {
		lua_writestringerror("%s: ", pname);
	}
  	lua_writestringerror("%s\n", msg);
}

/*
** Check whether 'status' is not OK and, if so, prints the error
** message on the top of the stack. It assumes that the error object
** is a string, as it was either generated by Lua or by 'lnode_message_handler'.
*/
static int lnode_report_message (lua_State *L, int status) {
  	if (status != LUA_OK) {
    	const char *msg = lua_tostring(L, -1);
    	lnode_print_message(progname, msg);
    	lua_pop(L, 1);  /* remove message */
  	}
  	return status;
}

/*
** Message handler used to run all chunks
*/
static int lnode_message_handler (lua_State *L) {
	const char *msg = lua_tostring(L, 1);
	if (msg == NULL) {  /* is error object not a string? */
		if (luaL_callmeta(L, 1, "__tostring") &&  /* does it have a metamethod */
			lua_type(L, -1) == LUA_TSTRING) {  /* that produces a string? */
			return 1;  /* that is the message */
		} else {
			msg = lua_pushfstring(L, "(error object is a %s value)",
								luaL_typename(L, 1));
		}
	}
	
	luaL_traceback(L, L, msg, 1);  /* append a standard traceback */
	return 1;  /* return the traceback */
}

/*
** Hook set by signal function to stop the interpreter.
*/
static void lnode_stop (lua_State *L, lua_Debug *ar) {
	(void)ar;  /* unused arg. */
	lua_sethook(L, NULL, 0, 0);  /* reset hook */
	luaL_error(L, "interrupted!");
}

/*
** Function to be called at a C signal. Because a C signal cannot
** just change a Lua state (as there is no proper synchronization),
** this function only sets a hook that, when called, will stop the
** interpreter.
*/
static void lnode_signal_handler (int i) {
  	signal(i, SIG_DFL); /* if another SIGINT happens, terminate process */
  	lua_sethook(globalL, lnode_stop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

/*
** Interface to 'lua_pcall', which sets appropriate message function
** and C-signal handler. Used to run all chunks.
*/
static int lnode_docall (lua_State *L, int narg, int nres) {
	int status;
	int base = lua_gettop(L) - narg;  /* function index */
	lua_pushcfunction(L, lnode_message_handler);  /* push message handler */
	lua_insert(L, base);  /* put it under function and args */
	globalL = L;  /* to be available to 'lnode_signal_handler' */
	signal(SIGINT, lnode_signal_handler);  /* set C-signal handler */
	status = lua_pcall(L, narg, nres, base);
	signal(SIGINT, SIG_DFL); /* reset C-signal handler */
	lua_remove(L, base);  /* remove message handler from the stack */
	return status;
}

static int lnode_dochunk (lua_State *L, int status) {
  	if (status == LUA_OK) {
		status = lnode_docall(L, 0, 0);
	}

  	return lnode_report_message(L, status);
}

static int lnode_dostring (lua_State *L, const char *s, const char *name) {
  	return lnode_dochunk(L, luaL_loadbuffer(L, s, strlen(s), name));
}

static int lnode_dofile (lua_State *L, const char *filename) {
	if ((filename == NULL) || (*filename == 0)) {
		return lnode_dochunk(L, luaL_loadfile(L, filename));
	}

	char pathname[PATH_MAX];
	memset(pathname, 0, sizeof(pathname));

	int isFile = 1;
	uv_fs_t req;
	uv_stat_t* stat;
	int ret = uv_fs_stat(NULL, &req, filename, NULL);
	if (ret == 0) {
		stat = &req.statbuf;

		if (S_ISDIR(stat->st_mode)) {
			// path to lua/app.lua
			strncpy(pathname, filename, PATH_MAX);
			strncat(pathname, "/lua/app.lua", PATH_MAX);
			filename = pathname;

		} else {
			size_t len = strlen(filename);
			if (len > 4) {
				const char *p = filename + len - 4;
				// printf("ext: %s %d\r\n", p, strncmp(p, ".zip", PATH_MAX));

				if (strncmp(p, ".zip", PATH_MAX) == 0) {
					snprintf(pathname, PATH_MAX, "require('app').open('%s');", filename);
					isFile = 0;
				}
			}
		}
	}

	uv_fs_req_cleanup(&req);

	if (isFile) {
  		return lnode_dochunk(L, luaL_loadfile(L, filename));

	} else {
		return lnode_dostring(L, pathname, "@/$core/lnode/init.lua");
	}
}

/*
** Calls 'require(name)' and stores the result in a global variable
** with the given name.
*/
static int lnode_dolibrary (lua_State *L, const char *name) {
	int status;
	lua_getglobal(L, "require");
	lua_pushstring(L, name);
	status = lnode_docall(L, 1, 1);  /* call 'require(name)' */
	if (status == LUA_OK) {
		lua_setglobal(L, name);  /* global[name] = require return */
	}
	return lnode_report_message(L, status);
}

static int lnode_init (lua_State *L) {
#ifdef NODE_LUA_RESOURCE
	const char* data = (const char*)init_data;
	return lnode_dostring(L, data, "init");
	
#else
	lnode_dolibrary(L, "init");
#endif
	return 0;
}

/**
 * Call this method at the end of each thread to close the relevant Lua
 * virtual machine and release the associated resources.
 */
static void lnode_vm_release(lua_State* L) {
  	lua_close(L);
}

static int lnode_lua_init(lua_State *L, int hasIgnore) {
    if (hasIgnore != 0) {
        lua_pushboolean(L, 1); /* signal for libraries to ignore env. vars. */
		lua_setfield(L, LUA_REGISTRYINDEX, "LUA_NOENV");
		return LUA_OK;
    }

	const char *name = "=" LUA_INITVARVERSION;
	const char *init = getenv(name + 1);
	if (init == NULL) {
		name = "=" LUA_INIT_VAR;
		init = getenv(name + 1); /* try alternative name */
	}

    // printf("init: %s\r\n", init);

	if (init == NULL) {
		return LUA_OK;

    } else if (init[0] == '@') {
		return lnode_dofile(L, init + 1);

    } else {
		return lnode_dostring(L, init, name);
    }
}

int lnode_run_applet(const char* name, int argc, char* argv[]) {
	lua_State* L = NULL;

	int res = 0;

	char pathname[PATH_MAX];
	memset(pathname, 0, PATH_MAX);

	// Hooks in libuv that need to be done in main.
	argv = uv_setup_args(argc, argv);

	// Create the lua state.
	L = luaL_newstate();
	if (L == NULL) {
		fprintf(stderr, "luaL_newstate has failed\n");
		return 1;
	}

	// init
	luaL_openlibs(L);  	// Add in the lua standard libraries
	lnode_openlibs(L); 	// Add in the lua ext libraries
	lnode_create_arg_table(L, argv, argc, 0);
	lnode_init_package_paths(L);
	lnode_init(L);
	luv_set_thread_cb(lnode_vm_acquire, lnode_vm_release);

	// call
	sprintf(pathname, "require('%s/app');", name);
	res = lnode_dostring(L, pathname, argv[0]);

	// exit
	lnode_dostring(L, "runLoop()", "=(C run)");
	lnode_dostring(L, "process:emit('exit')\n", "=(C exit)");
	lnode_vm_release(L);

	return res;
}

/** Prints the current lnode usage information. */
static int lnode_print_usage() 
{
  	char buffer[PATH_MAX];
  	memset(buffer, 0, sizeof(buffer));
  	sprintf(buffer, "\n"
	  	"usage: lnode [options] [script [args]]\n"
  		"Available options are:\n"
		  "\n"
  		"  -d      run as daemon\n"
  		"  -e stat execute string `stat`\n"
      "  -E      ignores environment variables\n"
  		"  -p      show package path information\n"
  		"  -l name require package `name`\n"
  		"  -v      show version information\n"
      "  --      stop handling options\n"
  		"  -       stop handling options and execute stdin\n"
		  "\n"
	);

    lua_writestring(buffer, strlen(buffer));
    lua_writeline();

    return 0;
}

static int lnode_print_runtime_info(lua_State* L) {
  char script[] =
    "local lnode = require('lnode')\n"
    "print('NODE_LUA_ROOT:\\n' .. lnode.NODE_LUA_ROOT .. '\\n')\n"
    "local path = string.gsub(package.path, ';', '\\n')"
  	"print('package.path:\\n' .. path)\n"
    "local cpath = string.gsub(package.cpath, ';', '\\n')"
  	"print('package.cpath:\\n' .. cpath)\n"
	"runLoop()\n"
  	;

  return lnode_dostring(L, script, "=(C print_runtime_info)");
}

int main(int argc, char* argv[]) {
	lua_State* L 	= NULL;

	int res 		= 0;
	int arg_index   = 1;
	int has_eval	= 0;
	int has_info	= 0;
	int has_script 	= 0;
	int has_require	= 0;
	int has_deamon  = 0;
    int has_version = 0;
    int has_error   = 0;
    int has_ignore  = 0;
    int i = 0;

#ifndef _WIN32
	signal(SIGPIPE, SIG_IGN);	// 13) 管道破裂: Write a pipe that does not have a read port

	signal(SIGHUP, SIG_IGN);
#endif

	char pathBuffer[PATH_MAX];
	memset(pathBuffer, 0, PATH_MAX);
	lnode_get_filename(argv[0], pathBuffer);

#ifdef _WIN32
	// get basename
	size_t len = strlen(pathBuffer);
	char* p = pathBuffer + len - 1;
	while (p > pathBuffer) {
		if (*p == '.') {
			*p = '\0';
			break;
		}
		p--;
	}
#endif

	// applet
	if (strcmp(pathBuffer, "lnode") != 0) {
		return lnode_run_applet(pathBuffer, argc, argv);
	}

	// Hooks in libuv that need to be done in main.
	argv = uv_setup_args(argc, argv);

	// while (argc >= 2) {
    for (i = 1; argv[i] != NULL; i++) {
		const char* option = argv[i];

		if (strcmp(option, "-d") == 0) {
            has_deamon = i; // Runs the current script in the background

		} else if (strcmp(option, "-p") == 0) {
			has_info = i;

		} else if (strcmp(option, "-e") == 0) {
            i++;

            if (argv[i] == NULL || argv[i][0] == '-') {
                has_error = i;
                printf("invalid execute arg\r\n");
                break;
            }

			has_eval = i;

		} else if (strcmp(option, "-l") == 0) {
            i++;

            if (argv[i] == NULL || argv[i][0] == '-') {
                printf("invalid require arg\r\n");
                has_error = 1;
                break;
            }

			has_require = i;

		} else if (strcmp(option, "-v") == 0) {
            has_version = i;

        } else if (strcmp(option, "-E") == 0) {
            has_ignore = i;    

		} else if (strcmp(option, "-") == 0) {
			has_script = i; // Read Lua script content from the pipeline

        } else if (strcmp(option, "--") == 0) {
            arg_index = i + 1;
            break;

		} else if (option[0] == '-') {
            printf("unrecognized option: %s\r\n", option);
            has_error = 1;
            break;
			
		} else {
            break;
        }

        arg_index = i + 1;
	}

    if (has_error) {
		// 发现参数错误
		lnode_print_usage();
        return -107;

    } else if (has_version) {
		// 仅仅打印版本号
        return lnode_print_version();
    }

    if (has_deamon) {
        lnode_run_as_daemon();
    }

	// Create the lua state.
	L = luaL_newstate();
	if (L == NULL) {
		fprintf(stderr, "luaL_newstate has failed\n");
		return 1;
	}

	// init
	luaL_openlibs(L);  	// Add in the lua standard libraries
	lnode_openlibs(L); 	// Add in the lua ext libraries
	lnode_create_arg_table(L, argv, argc, has_eval ? arg_index - 1 : arg_index);
	lnode_init_package_paths(L);
    lnode_lua_init(L, has_ignore);
	lnode_init(L);

	if (has_info) {
		// 仅仅打印运行环境信息
		res = lnode_print_runtime_info(L);
		return res;
	}

	luv_set_thread_cb(lnode_vm_acquire, lnode_vm_release);
	
	// call eval or require
	if (has_eval || has_require) {
        for (i = 1; i <= arg_index; i++) {
            const char* option = argv[i];
			if (option == NULL) {
				break;

			} else if (strcmp(option, "-e") == 0) {
                i++;

				// eval
                const char* text = argv[i];
                res = lnode_dostring(L, text, "=(C eval)");

            } else if (strcmp(option, "-l") == 0) {
                i++;

				// load library
                const char* text = argv[i];
                res = lnode_dolibrary(L, text);
            }
        }
    }

	if (!has_eval) {
		// filename
		const char* filename = NULL;
		if ((arg_index > 0) && (arg_index < argc)) {
			filename = argv[arg_index];
			has_script = arg_index;
		}

		if (has_script) {
			res = lnode_dofile(L, filename);
			
		} else if (argc <= 1) {
			lnode_print_version();
			lnode_print_usage();
		}
	}

	// exit
	lnode_dostring(L, "runLoop()", "=(C run)");
	lnode_dostring(L, "process:emit('exit')\n", "=(C exit)");
	lnode_vm_release(L);

	return res;
}
