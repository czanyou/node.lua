/*
 *  Copyright 2015 The Lnode Authors. All Rights Reserved.
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
#include "luv.h"

#ifndef _LUV_OS
#define _LUV_OS

///////////////////////////////////////////////////////////////////////////////
// platform function

/* Identify known platforms by name.  */
#if defined(__linux__) || defined(__linux)
# define PLATFORM_ID "linux"

#include <sys/statfs.h>

#elif defined(__APPLE__)
# define PLATFORM_ID "darwin"

#include <sys/mount.h>

#elif defined(__WIN32__) || defined(_WIN32)
# define PLATFORM_ID "win32"

#elif defined(__FreeBSD__) || defined(__FreeBSD)
# define PLATFORM_ID "freebsd"

#elif defined(__OpenBSD__) || defined(__OPENBSD)
# define PLATFORM_ID "openbsd"

#elif defined(__sun__) || defined(__sun)
# define PLATFORM_ID "sunos"

#else /* unknown platform */
# define PLATFORM_ID ""
#endif

static int luv_os_platform(lua_State* L) {
 	lua_pushstring(L, PLATFORM_ID);
 	return 1;
}

///////////////////////////////////////////////////////////////////////////////
// arch function

/* For windows compilers MSVC and Intel we can determine
   the architecture of the compiler being used.  This is because
   the compilers do not have flags that can change the architecture,
   but rather depend on which compiler is being used
*/

#if defined(__x86_64__) || defined(__ia64__) || defined(_M_IA64) || defined(__amd64__) || defined(__AMD64__) || defined(_WIN64) || defined(WIN64)
#  define ARCHITECTURE_ID "x64"

#elif defined(__i386__) || defined(_X86_) 
#  define ARCHITECTURE_ID "ia32"

#elif defined(__arm__) || defined(_ARM_)
#  define ARCHITECTURE_ID "arm"

#elif defined(__mips__) || defined(_MIPS_)
#  define ARCHITECTURE_ID "mips"

#else
#  define ARCHITECTURE_ID ""
#endif

#endif

static int luv_os_arch(lua_State* L) {
 	lua_pushstring(L, ARCHITECTURE_ID);
 	return 1;
}

///////////////////////////////////////////////////////////////////////////////
// fork function

static int luv_os_fork(lua_State* L) {
	int ret = 0;

	#ifndef _WIN32
	ret = fork();
	#endif

	lua_pushinteger(L, ret);
 	return 1;
}

///////////////////////////////////////////////////////////////////////////////
// file lock function

static int luv_os_file_lock_control(int fd, int type, off_t offset, off_t len)
{
#ifndef _WIN32

	struct flock lock;
	lock.l_type   = type;		/* F_RDLCK, F_WRLCK, F_UNLCK */
	lock.l_start  = offset;		/* byte offset, relative to l_whence */
	lock.l_whence = SEEK_SET;	/* SEEK_SET, SEEK_CUR, SEEK_END */
	lock.l_len	  = len;		/* #bytes (0 means to EOF) */
	return fcntl(fd, F_SETLK, &lock);

#endif

	return 1;
}

static int luv_os_file_lock(lua_State* L) {
	int fd = (int)luaL_checkinteger(L, 1);

	size_t size = 0;
	char* mode = (char*)luaL_checklstring(L, 2, &size);

	off_t offset = 0;
	off_t len = 0;
	int type = -1;

#ifndef _WIN32

	if (fd <= 0 || mode == NULL || size <= 0) {
		type = -1;

	} else if (*mode == 'r') {
		type = F_RDLCK;

	} else if (*mode == 'w') {
		type = F_WRLCK;

	} else if (*mode == 'u') {
		type = F_UNLCK;
	}

#endif

	int ret = 1;
	if (type != -1) {
		ret = luv_os_file_lock_control(fd, type, offset, len);
	}

	lua_pushinteger(L, ret);
 	return 1;
}

///////////////////////////////////////////////////////////////////////////////
// statfs function

#ifndef _WIN32

static int luv_os_push_statfs_table(lua_State* L, struct statfs* s) {
	const char* type = NULL;
	lua_createtable(L, 0, 23);

	lua_pushinteger(L, s->f_bsize);
	lua_setfield(L, -2, "bsize");

	lua_pushinteger(L, s->f_blocks);
	lua_setfield(L, -2, "blocks");

	lua_pushinteger(L, s->f_bfree);
	lua_setfield(L, -2, "bfree");

	lua_pushinteger(L, s->f_type);
	lua_setfield(L, -2, "type");

#ifdef __linux
	lua_pushinteger(L, s->f_namelen);
	lua_setfield(L, -2, "namelen"); 
#endif
	
	return 0;
}

#endif

static int luv_os_statfs(lua_State* L) {
	size_t size = 0;
	char* name = (char*)luaL_checklstring(L, 1, &size);
	if (name == NULL || size <= 0) {
		return 0;
	}

#ifndef _WIN32
	struct statfs fs;
	if (statfs(name, &fs) == 0) {
		luv_os_push_statfs_table(L, &fs);
		return 1;
	}
#endif

	return 0;
}

///////////////////////////////////////////////////////////////////////////////
// string compare

#ifdef _MSC_VER
int strcasecmp(const char *s1, const char *s2);
int strncasecmp(const char *s1, const char *s2, register int n);
#endif

#ifdef _MSC_VER
int strcasecmp(const char *s1, const char *s2)
{
   return stricmp(s1, s2);
}

int strncasecmp(const char *s1, const char *s2, register int n)
{
  return strnicmp(s1, s2, n);
}
#endif

