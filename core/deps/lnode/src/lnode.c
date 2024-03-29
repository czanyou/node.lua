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

#include <string.h>
#include <stdlib.h>

#ifdef _WIN32
#include <winsock2.h>
#include <windows.h>
#include <io.h>

#define access _access

#else
#include <unistd.h>
#include <errno.h>
#endif // _WIN32

#ifdef NODE_LUA_RESOURCE
#include "../../../../build/packages.c"
#endif

#define WITH_CJSON        1
#define WITH_LUTILS       1
#define WITH_MINIZ        1

LUALIB_API int luaopen_cjson(lua_State* const L);
LUALIB_API int luaopen_lsqlite(lua_State* const L);
LUALIB_API int luaopen_lutils(lua_State* const L);
LUALIB_API int luaopen_lmbedtls_cipher(lua_State* const L);
LUALIB_API int luaopen_lmbedtls_md(lua_State* const L);
LUALIB_API int luaopen_lmbedtls_pk(lua_State* const L);
LUALIB_API int luaopen_lmbedtls_rng(lua_State* const L);
LUALIB_API int luaopen_lmbedtls_tls(lua_State* const L);
LUALIB_API int luaopen_lmbedtls_x509_crl(lua_State* const L);
LUALIB_API int luaopen_lmbedtls_x509_csr(lua_State* const L);
LUALIB_API int luaopen_lmbedtls(lua_State* const L);
LUALIB_API int luaopen_miniz(lua_State* const L);
LUALIB_API int luaopen_lmodbus(lua_State* const L);
LUALIB_API int luaopen_snapshot(lua_State* const L);

static int lua_table_set(lua_State *L, const char* key, const char* value)
{
  if (key == NULL || value == 0) {
    return -1;
  }

  lua_pushstring(L, value);
  lua_setfield(L, -2, key);

  return 0;
}

static int lua_table_set_data(lua_State *L, const char* key, const char* value, size_t length)
{
  if (key == NULL || value == 0) {
    return -1;
  }

  lua_pushlstring(L, value, length);
  lua_setfield(L, -2, key);

  return 0;
}

static int lnode_dos2unix_path(char* buffer) {
  if (buffer == NULL) {
    return -1;
  }

  char* p = buffer;
	while (*p != '\0') {
		if (*p == '\\') {
			*p = '/';
		}
		p++;
	}

  return 0;
}

static int lnode_file_exists(const char* basePath, const char* subPath) {
  char filename[PATH_MAX];
  memset(filename, 0, sizeof(filename));

  if (basePath) {
    strncpy(filename, basePath, PATH_MAX);
  }

  if (subPath) {
    strncat(filename, subPath, PATH_MAX);
  }

  return access(filename, 0) == 0;
}

static int lnode_get_exepath(char* buffer, size_t size) {
  if (buffer == NULL || size <= 0) {
    return -1;
  }

  memset(buffer, 0, size);
  return uv_exepath(buffer, &size);
}

static int lnode_get_dirname(char* buffer) {
  if (buffer == NULL) {
    return -1;
  }

  size_t len = strlen(buffer);
  char* p = buffer + len - 1;
  while (p > buffer) {
    if (*p == '/') {
      *p = '\0';
      return 0;
    }
    p--;
  }

  return -1;
}

/** Prints the current lnode version information. */
LUALIB_API int lnode_print_version()
{
    char buffer[PATH_MAX];
    memset(buffer, 0, sizeof(buffer));

#ifdef WITH_INIT
    sprintf(buffer, "lnode %d.%d.%s (Lua %s.%s.%s, libuv %s, build %s %s)",
            LNODE_MAJOR_VERSION, LNODE_MINOR_VERSION, core_build,
            LUA_VERSION_MAJOR, LUA_VERSION_MINOR, LUA_VERSION_RELEASE,
            uv_version_string(), __DATE__, __TIME__);
#else
    sprintf(buffer, "lnode %d.%d (Lua %s.%s.%s, libuv %s, build %s %s)",
            LNODE_MAJOR_VERSION, LNODE_MINOR_VERSION,
            LUA_VERSION_MAJOR, LUA_VERSION_MINOR, LUA_VERSION_RELEASE,
            uv_version_string(), __DATE__, __TIME__);
#endif

    lua_writestring(buffer, strlen(buffer));
    lua_writeline();

    return 0;
}

LUALIB_API int lnode_get_filename(const char* path, char* buffer) {
  if (buffer == NULL || path == NULL) {
    return -1;
  }

  size_t len = strlen(path);
  const char* p = path + len - 1;
  while (p > path) {
    if (*p == '/' || *p == '\\') {
      p++;
      break;
    }
    p--;
  }

  strncpy(buffer, p, PATH_MAX);

  return 0;
}

#ifdef _WIN32

const char* lnode_get_realpath(const char* filename, char* realname) {
	if (filename == NULL || realname == NULL) {
		return filename;
	}

	GetFullPathNameA(filename, PATH_MAX, realname, NULL);
  lnode_dos2unix_path(realname);

	return realname;
}

static int lnode_get_rootpath(char* buffer) {
  char pathName[PATH_MAX];
  memset(pathName, 0, sizeof(pathName));

  // Dev path
  lnode_get_exepath(pathName, PATH_MAX);
  lnode_dos2unix_path(pathName);
  lnode_get_dirname(pathName);
  lnode_get_dirname(pathName);

  strncpy(buffer, pathName, PATH_MAX);
  return 0;
}

#else

const char* lnode_get_realpath(const char* filename, char* realname) {
	if (filename == NULL || realname == NULL) {
		return filename;
	}

	realpath(filename, realname);

	return realname;
}

static int lnode_get_rootpath(char* buffer) {
  const char* root = NODE_LUA_ROOT;

  char exePath[PATH_MAX];
  memset(exePath, 0, sizeof(exePath));

  // NODE_LUA_ROOT
  const char *rootPath = getenv("NODE_LUA_ROOT");
  if (rootPath) {
    if (lnode_file_exists(rootPath, "/bin")) { // /path/NODE_LUA_ROOT/bin
      root = rootPath;
      goto EXIT;
    }
  }

  // TODO
  lnode_get_exepath(exePath, PATH_MAX); // /path/to/bin/lnode
  lnode_get_dirname(exePath); // /path/to/bin
  lnode_get_dirname(exePath); // /path/to
  if (lnode_file_exists(exePath, "/app/lpm")) { // /path/to/app/lpm
    root = exePath;

  } else if (lnode_file_exists(exePath, "/app/")) { // /path/to/app/
    root = exePath;
  }

  EXIT:

  strncpy(buffer, root, PATH_MAX);
  return 0;
}

#endif

static int lnode_load(lua_State* L) {
	const char* name = luaL_optstring(L, 1, NULL);

  #ifdef WITH_INIT
  if (strncmp(name, "init", 4) == 0) {
    lua_pushlstring(L, init_data, init_size);
  } else {
	  lua_pushlstring(L, core_data, core_size);
  }
	return 1;
  #else
  return 0;
  #endif
}

static const luaL_Reg lnode_functions[] = {
  {"load",	lnode_load},
  {NULL, NULL}
};

LUALIB_API int luaopen_lnode(lua_State *L)
{
  char buffer[1024];
  // lua_newtable(L); // lnode
  luaL_newlib(L, lnode_functions);

  // lnode version
#ifdef LNODE_MAJOR_VERSION
  sprintf(buffer, "%d.%d", LNODE_MAJOR_VERSION, LNODE_MINOR_VERSION);
  lua_table_set(L, "version", buffer);
#endif

  // lnode root path
  char rootPath[PATH_MAX];
  memset(rootPath, 0, sizeof(rootPath));
  lnode_get_rootpath(rootPath);
  lua_table_set(L, "NODE_LUA_ROOT", rootPath);
  lua_table_set(L, "NODE_LUA_PATH", NODE_LUA_ROOT);

#ifdef NODE_LUA_BOARD
  lua_table_set(L, "board", NODE_LUA_BOARD);
#endif

#ifdef WITH_INIT
  lua_table_set(L, "init", "init");
  lua_table_set(L, "build", core_build);
#endif

  lua_newtable(L); // versions

  // libuv version
  lua_table_set(L, "uv", uv_version_string());

  // lua version
  sprintf(buffer, "%s.%s.%s", LUA_VERSION_MAJOR, LUA_VERSION_MINOR, LUA_VERSION_RELEASE);
  lua_table_set(L, "lua", buffer);

  lua_setfield(L, -2, "versions");

  return 1;
}

// ////////////////////////////////////////////////////////////////////////////
// public methods

/** Let current program runs into the background. */
LUALIB_API int lnode_run_as_daemon() {

#ifndef _WIN32

  // fork off the parent process & let it terminate if forking was successful. 
  // -> Because the parent process has terminated, the child process now runs in the background.
  if (fork() != 0) {
    exit(EXIT_SUCCESS);
  }

  // Create a new session. The calling process becomes the leader of the new 
  // session and the process group leader of the new process group. 
  // The process is now detached from its controlling terminal
  if (setsid() < 0) {
    exit(EXIT_FAILURE);
  }

  signal(SIGCHLD, SIG_IGN);
  signal(SIGHUP, SIG_IGN);

  // fork again & let the parent process terminate to ensure that you get rid 
  // of the session leading process. (Only session leaders may get a TTY again.)
  if (fork() != 0) {
    exit(EXIT_FAILURE);
  }

  // Change the file mode mask according to the needs of the daemon.
  umask(022);
  
#endif

  return 0;
}

/**
 * Read and run the Lua script from the file.
 * @param filename The Lua script file name to load and run
 * @return Lua script can return an integer value as the return value of this
 *   method, if not specified by default returns 0.
 */
LUALIB_API int lnode_call_file(lua_State* L, const char* filename) {
  // Load the *.lua script

  if (luaL_loadfilex(L, filename, NULL)) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return -1;
  }

  // Start the main script.
  if (lua_pcall(L, 0, 1, 0)) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return -1;
  }

  // Use the return value from the script as process exit code.
  int ret = 0;
  if (lua_type(L, -1) == LUA_TNUMBER) {
    ret = lua_tointeger(L, -1);
  }

  return ret;
}

/**
 * Runs the specified Lua script
 */
LUALIB_API int lnode_call_script(lua_State* L, const char* script, const char* name) {
  if (script == NULL) {
    return -1;
  }

  if (name == NULL) {
    name = script;
  }

  // Load the init.lua script
  if (luaL_loadbuffer(L, script, strlen(script), name)) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return -1;
  }

  // Start the main script.
  if (lua_pcall(L, 0, 1, 0)) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return -1;
  }

  // Use the return value from the script as process exit code.
  int ret = 0;
  if (lua_type(L, -1) == LUA_TNUMBER) {
    ret = lua_tointeger(L, -1);
  }

  return ret;
}

LUALIB_API int lnode_init_package_paths(lua_State* L) {
  char buffer[PATH_MAX];
  memset(buffer, 0, sizeof(buffer));

  char root[PATH_MAX];
  memset(root, 0, sizeof(root));
  lnode_get_rootpath(root);

#ifdef _WIN32
  const char* fmt = "package.path='"
    "%s/lua/?.lua;"
    "%s/lua/?/init.lua;"
    "%s/core/lua/?.lua;"
    "%s/core/lua/?/init.lua;"
    "./lua/?.lua;"
    "./lua/?/init.lua;"
    "./?.lua;"
    "./?/init.lua;"
    "'\n"
    "package.cpath='"
    "%s/bin/?.dll;"
    "./?.dll;"
    "%s/bin/loadall.dll;"
    "'\n";

  snprintf(buffer, PATH_MAX, fmt,
    root, root, root, root, root, root);

#else
  const char* fmt = "package.path='"
    "%s/lua/?.lua;"
    "%s/lua/?/init.lua;"
    "%s/lib/?.lua;"
    "%s/lib/?/init.lua;"
    "./lua/?.lua;"
    "./lua/?/init.lua;"
    "./?.lua;"
    "./?/init.lua;"
    "'\n"
    "package.cpath='"
    "%s/bin/?.so;"
    "%s/lib/?.so;"
    "./?.so;"
    "%s/bin/loadall.so;"
    "'\n";

  snprintf(buffer, PATH_MAX, fmt,
    root, root, root, root,
    root, root, root);
#endif
  //printf("%s\n", buffer);

  return lnode_call_script(L, buffer, "path.lua");
}

/*
** Create the 'arg' table, which stores all arguments from the
** command line ('argv'). It should be aligned so that, at index 0,
** it has 'argv[script]', which is the script name. The arguments
** to the script (everything after 'script') go to positive indices;
** other arguments (before the script name) go to negative indices.
** If there is no script name, assume interpreter's name as base.
*/
LUALIB_API int lnode_create_arg_table(lua_State *L, char **argv, int argc, int script)
{
    int i, narg;

    if (script == argc) {
        script = 0; /* no script name? */
    }

    narg = argc - (script + 1); /* number of positive indices */

    lua_createtable(L, narg, script + 1);
    for (i = 0; i < argc; i++) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i - script);
    }
    lua_setglobal(L, "arg");

    return 0;
}

/**
 * Open and register the lnode related core module
 */
LUALIB_API int lnode_openlibs(lua_State *L)
{
    // Get package.loaded, so we can store uv in it.
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "loaded");
    lua_remove(L, -2); // Remove package

    // Store uv module definition at loaded.luv
    luaopen_luv(L);
    lua_setfield(L, -2, "luv");
    lua_pop(L, 1);

    // Get package.preload so we can store builtins in it.
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "preload");
    lua_remove(L, -2); // Remove package

#ifdef WITH_CJSON
    lua_pushcfunction(L, luaopen_cjson);
    lua_setfield(L, -2, "cjson");
#endif

#ifdef WITH_LUTILS
    lua_pushcfunction(L, luaopen_lutils);
    lua_setfield(L, -2, "lutils");
#endif

#ifdef WITH_LUTILS
    lua_pushcfunction(L, luaopen_snapshot);
    lua_setfield(L, -2, "snapshot");
#endif

#ifdef WITH_MINIZ
    lua_pushcfunction(L, luaopen_miniz);
    lua_setfield(L, -2, "miniz");
#endif

#ifdef BUILD_SQLITE
    lua_pushcfunction(L, luaopen_lsqlite);
    lua_setfield(L, -2, "lsqlite");
#endif

#ifdef BUILD_MODBUS
    lua_pushcfunction(L, luaopen_lmodbus);
    lua_setfield(L, -2, "lmodbus");
#endif

#ifdef BUILD_MBEDTLS
    lua_pushcfunction(L, luaopen_lmbedtls_pk);
    lua_setfield(L, -2, "lmbedtls.pk");

    lua_pushcfunction(L, luaopen_lmbedtls_md);
    lua_setfield(L, -2, "lmbedtls.md");

    lua_pushcfunction(L, luaopen_lmbedtls_rng);
    lua_setfield(L, -2, "lmbedtls.rng");

    lua_pushcfunction(L, luaopen_lmbedtls_tls);
    lua_setfield(L, -2, "lmbedtls.tls");

    lua_pushcfunction(L, luaopen_lmbedtls_cipher);
    lua_setfield(L, -2, "lmbedtls.cipher");
    
    lua_pushcfunction(L, luaopen_lmbedtls_x509_crl);
    lua_setfield(L, -2, "lmbedtls.x509.crl");

    lua_pushcfunction(L, luaopen_lmbedtls_x509_csr);
    lua_setfield(L, -2, "lmbedtls.x509.csr");
#endif

    // Store lnode module definition at preload.lnode
    lua_pushcfunction(L, luaopen_lnode);
    lua_setfield(L, -2, "lnode");

    lua_pop(L, 1);

    return 0;
}
