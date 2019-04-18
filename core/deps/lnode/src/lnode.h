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
#ifndef _LNODE_H
#define _LNODE_H

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#include "uv.h"
#include "luv.h"

#ifndef LNODE_MAJOR_VERSION
#define LNODE_MAJOR_VERSION 4
#define LNODE_MINOR_VERSION 1
#endif

#ifndef NODE_LUA_ROOT
#define NODE_LUA_ROOT '/usr/local/lnode/'
#endif

LUALIB_API int lnode_call_file(lua_State* L, const char* filename);
LUALIB_API int lnode_call_script(lua_State* L, const char* script, const char* name);
LUALIB_API int lnode_create_arg_table(lua_State *L, char **argv, int argc, int offset);
LUALIB_API int lnode_init(lua_State* L);
LUALIB_API int lnode_openlibs(lua_State* L);
LUALIB_API int lnode_run_as_deamon();
LUALIB_API int lnode_get_script_path(char* buffer, size_t size);
LUALIB_API int lnode_set_script_path(const char* buffer);

const char* lnode_get_realpath(const char* filename, char* realname);

#endif // _LNODE_H
