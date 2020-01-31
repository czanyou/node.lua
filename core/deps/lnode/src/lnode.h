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

/**
 * 创建 arg 参数数组
 * @param argv 参数列表
 * @param argc 参数数量
 * @param offset arg[0] 参数偏移位置
 */
LUALIB_API int lnode_create_arg_table(lua_State *L, char **argv, int argc, int offset);

/**
 * 初始化 package.path 和 package.cpath
 */ 
LUALIB_API int lnode_init_package_paths(lua_State* L);

/**
 * 注册 lnode 核心模块到预加载列表中
 */ 
LUALIB_API int lnode_openlibs(lua_State* L);

/**
 * 在后台运行
 */
LUALIB_API int lnode_run_as_daemon();

/**
 * 返回指定的路径中的文件名部分
 * 如: `/bin/test/tcc` 将返回 `tcc`
 */
LUALIB_API int lnode_get_filename(const char* path, char* buffer);

#endif // _LNODE_H
