# Node.lua Native 模块

## 概述

Node.lua 使用 C/C++ 语言以及 Lua C API 来实现 Native 扩展模块.

所以开发 Node.lua 扩展模块和开发 Lua 扩展模块基本没有区别.

扩展模块既可以直接集成在 lnode 主程序中, 也可以编译为单独的动态库 (so/dll), 注意在不同操作系统中对单独的动态库支持并不一样.

## 参考

### 导出方法

```c
static const luaL_Reg lutils_functions[] = {
 
  // os.c
  { "os_arch",          luv_os_arch },
  { "os_file_lock",     luv_os_file_lock },
  { "os_fork",          luv_os_fork },
  { "os_platform",      luv_os_platform },
  { "os_statfs",        luv_os_statfs },

  { NULL, NULL }
};

LUALIB_API int luaopen_lutils(lua_State *L) {

  luaL_newlib(L, lutils_functions);

  return 1;
}

```

### 导出类

```c

// 类名
#define LUV_BUFFER "luv_buffer_t"

/** buffer 类成员方法定义. */
static const luaL_Reg luv_buffer_functions[] = {
	{ "get_byte",		luv_buffer_get_byte },
	{ "put_byte",		luv_buffer_put_byte },
	{ "size",			luv_buffer_size },
	{ "to_string",		luv_buffer_to_string },
	{ NULL, NULL }
};

/** 初始化 buffer 类 */
static void luv_buffer_init(lua_State* L) {
	// 创建 buffer 类
	luaL_newmetatable(L, LUV_BUFFER);
    // buffer meta table index = -2

    // 成员方法元方法
	luaL_newlib(L, luv_buffer_functions);
	lua_setfield(L, -2, "__index");

    // 自动垃圾回收元方法
	lua_pushcfunction(L, luv_buffer_close);
	lua_setfield(L, -2, "__gc");

    // 转字符串元方法
	lua_pushcfunction(L, luv_buffer_tostring);
	lua_setfield(L, -2, "__tostring");	

	lua_pop(L, 1); // pop buffer meta table
}

/** lutils 模块静态方法定义 */
static const luaL_Reg lutils_functions[] = {
 
    // 导出 buffer 构建方法
    { "new_buffer",       luv_buffer_new },
    { NULL, NULL }
};

/** 导出名为 lutils 的 NAPI 模块 */
LUALIB_API int luaopen_lutils(lua_State *L) {

    // lutils 模块和方法
    luaL_newlib(L, lutils_functions);

    // 初始化 buffer 类
    luv_buffer_init(L);

    // Set module name / version fields
    lua_pushliteral(l, "lutils");
    lua_setfield(l, -2, "NAME");

    lua_pushliteral(l, "1.0.8");
    lua_setfield(l, -2, "VERSION");

    return 1;
}

```

可以通过下面的 Lua 脚本调用上述的模块

```lua
local lutils = require('lutils')
local buffer = lutils.new_buffer()

console.log(buffer)

buffer:put_byte(100)
buffer:get_byte(1)
local size = buffer:size()

```

### 回调函数

```c

/*
** Message handler used to run all chunks
*/
static int lutils_message_handler (lua_State *L) {
  const char *msg = lua_tostring(L, 1);
  if (msg == NULL) {  /* is error object not a string? */
    if (luaL_callmeta(L, 1, "__tostring") &&  /* does it have a metamethod */
        lua_type(L, -1) == LUA_TSTRING)  /* that produces a string? */
      return 1;  /* that is the message */
    else
      msg = lua_pushfstring(L, "(error object is a %s value)",
                               luaL_typename(L, 1));
  }
  luaL_traceback(L, L, msg, 1);  /* append a standard traceback */
  return 1;  /* return the traceback */
}

static int docall (lua_State *L, int narg, int nres) {
  int status;
  int base = lua_gettop(L) - narg;  /* function index */
  lua_pushcfunction(L, lutils_message_handler);  /* push message handler */
  lua_insert(L, base);  /* put it under function and args */
  //signal(SIGINT, laction);  /* set C-signal handler */
  status = lua_pcall(L, narg, nres, base);
  //signal(SIGINT, SIG_DFL); /* reset C-signal handler */
  lua_remove(L, base);  /* remove message handler from the stack */
  return status;
}

static void lutils_callback_release(lutils_t* lutils)
{
	if (lutils == NULL) {
		return;
	}

	lua_State* L = lutils->fState;

	if (lutils->fCallback != LUA_NOREF) {
  		luaL_unref(L, LUA_REGISTRYINDEX, lutils->fCallback);
  		lutils->fCallback = LUA_NOREF;
  	}
}

static void lutils_callback_check(lutils_t* lutils, int index) 
{
	if (lutils == NULL) {
		return;
	}

	lua_State* L = lutils->fState;
	lutils_callback_release(lutils);

  	luaL_checktype(L, index, LUA_TFUNCTION);
  	lutils->fCallback = luaL_ref(L, LUA_REGISTRYINDEX);
}

static void lutils_callback_call(lutils_t* lutils, int nargs) 
{
	if (lutils == NULL) {
		return;
	}

	lua_State* L = lutils->fState;

  	int ref = lutils->fCallback;
  	if (ref == LUA_NOREF) {
    	lua_pop(L, nargs);
    	return;
 	}

    // Get the callback
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);

    // And insert it before the args if there are any.
    if (nargs) {
      	lua_insert(L, -1 - nargs);
    }

    if (lua_pcall(L, nargs, 0, -2 - nargs)) {
      	LOG_W("Uncaught error in lutils callback: %s\n", lua_tostring(L, -1));
      	return;
    }
}

lua_pushlstring(L, buffer->data, buffer->length);
lutils_callback_call(lutils, 1);

```

### Lua 数据类型

Lua 数据类型包含 LUA_TNIL (0), LUA_TNUMBER, LUA_TBOOLEAN, LUA_TSTRING, LUA_TTABLE, LUA_TFUNCTION, LUA_TUSERDATA, LUA_TTHREAD, 以及 LUA_TLIGHTUSERDATA.

### 从 Lua 传递参数给 C

参数的索引都是从 1 开始

如果指定的参数存在且是指定的类型则返回这个类型的值, 其他则返回错误

- `luaL_checkany` 检查是否是任意类型的参数 (包含 nil)
- `luaL_checkinteger` 整数
- `luaL_checklstring` 字符串
- `luaL_checknumber` 数字
- `luaL_checkoption` 检查指定的参数是否是 enums
- `luaL_checkstring` 字符串
- `luaL_checktype` 检查指定参数的类型
- `luaL_checkudata` 用户数据

```c
static int test(lua_State *L) {
    size_t dataSize = 0;
    uint8_t *data = (uint8_t*)luaL_checklstring(L, 1, &dataSize);
    

    return 0;
}
```

可选参数

如果指定的参数是指定的类型则返回这个类型的值, 如果是空或者不存在则返回默认值, 其他则返回错误

- `luaL_optinteger` 整数
- `luaL_optlstring` 字符串
- `luaL_optnumber` 数字
- `luaL_optstring` 字符串


### 从 C 传递参数给 Lua

- `lua_pushboolean` 布尔值
- `lua_pushcclosure` C 闭包
- `lua_pushcfunction` C 函数
- `lua_pushfstring` 格式化字符串
- `lua_pushglobaltable` 全局环境变量表格
- `lua_pushinteger` 整数
- `lua_pushlightuserdata` 用户数据
- `lua_pushliteral` 字符串
- `lua_pushlstring` 字符串
- `lua_pushnil` 空值
- `lua_pushnumber` 数值
- `lua_pushstring` 字符串
- `lua_pushthread` 协程
- `lua_pushvalue` 任意值
- `lua_pushvfstring` 格式化字符串

最后返回 `返回` 参数个数.

示例

```c
static int test(lua_State *L) {
    lua_pushnil(L);
    lua_pushinteger(L, status);
    return 2;
}
```

