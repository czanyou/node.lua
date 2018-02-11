#include "ble_lua.h"

#define VISION_BLUETOOTH "lbluetooth_t"

static void lbluetooth_async_close_callback(uv_handle_t* handle);
static void lbluetooth_async_callback(uv_async_t *async);
static void lbluetooth_callback_call(lbluetooth_t* lbluetooth, int nargs);
static int  lbluetooth_release(lua_State* L, lbluetooth_t* ble);
static void lbluetooth_thread(void* arg);
static int  lbluetooth_wait_ready(int fd, double timeout);

#define LOG_W printf

//
int bt_device_info(int fd, int dev_id, long arg)
{
	struct hci_dev_info deviceInfo = { .dev_id = dev_id };
	char address[18];

	if (ioctl(fd, HCIGETDEVINFO, (void *) &deviceInfo)) {
		return 0;
	}

	ba2str(&deviceInfo.bdaddr, address);
	//LOG_W("\t%s\t%s\n", di.name, addr);
	return 0;
}

static int bt_device_close(lbluetooth_t* ble)
{
	int handler = ble->fHandler;
	if (handler >= 0) {
		ble->fHandler = -1;

		hci_close_dev(handler);	
	}
}

static int bt_device_list(void)
{
	// 枚举所有 HCI 设备
	hci_for_each_dev(HCI_UP, bt_device_info, 0);

	return 0;
}

//
static int bt_device_open(int deviceId)
{
	// function(dev_id)
	int fd = hci_open_dev(deviceId);
	if (fd < 0) {
		perror("Could not open device");
		return (-1);
	}

	// set no blocks
	int flags;
	flags = fcntl(fd, F_GETFL);
	flags |= O_NONBLOCK;
	
	if (fcntl(fd, F_SETFL, flags) == -1) {
		perror("fcntl error");
	}

	return fd;
}

static int bt_device_scan(lbluetooth_t* lbluetooth)
{
	int handler = lbluetooth->fHandler;

	uint8_t enable 		= 0x00;
	uint8_t filter_dup 	= 0x01;
	hci_le_set_scan_enable(handler, enable, filter_dup, 10000);

	//uint8_t scan_type 	= 0x00; // Passive mode
	//scan_type 			= 0x01; // Active mode

	uint8_t scan_type 	= lbluetooth->fScanType;

	uint16_t interval	= htobs(0x0010); // 指示两次扫描之间的间隔
	uint16_t window 	= htobs(0x0010); // 指示一次扫描的时间（即 RX 打开的时间）
	uint8_t own_type 	= LE_PUBLIC_ADDRESS; // LE_RANDOM_ADDRESS
	uint8_t filter_policy = 0x00; // 0x01: Whitelist

	// 2. scan parameters
	int err = hci_le_set_scan_parameters(handler, scan_type, interval, window, own_type, filter_policy, 10000);
	if (err < 0) {
		perror("Set scan parameters failed");
		return err;
	}

	// 3. enable scan
	enable     = 0x01;
	filter_dup = 0x00;
	err = hci_le_set_scan_enable(handler, enable, filter_dup, 10000);
	if (err < 0) {
		perror("Enable scan failed");
		return err;
	}

	return 0;
}

///////////////////////////////////////////////////////////////////////////////
// callback

uv_loop_t* lbluetooth_uv_loop(lua_State* L) {
	uv_loop_t* loop;
	lua_pushstring(L, "uv_loop");
	lua_rawget(L, LUA_REGISTRYINDEX);
	loop = (uv_loop_t*)lua_touserdata(L, -1);
	lua_pop(L, 1);
	return loop;
}

static void lbluetooth_async_callback(uv_async_t *async)
{
	if (async == NULL) {
		return;
	}

	lbluetooth_t* ble = (lbluetooth_t*)async->data;
	lua_State* L = ble->fState;

	while (TRUE) {
		queue_buffer_t* buffer = queue_pop(&ble->fQueue);
		if (buffer == NULL) {
			break;
		}

		lua_pushlstring(L, buffer->data, buffer->length);
		queue_buffer_free(buffer);

		lbluetooth_callback_call(ble, 1);
	}

	if (ble->fThreadState == LBLUETOOTH_STATE_INIT) {
		lbluetooth_release(L, ble);
	}
}

static void lbluetooth_async_close_callback(uv_handle_t* handle)
{
	if (handle) {
		free(handle);
	}
}

static void lbluetooth_callback_release(lbluetooth_t* lbluetooth)
{
	if (lbluetooth == NULL) {
		return;
	}

	lua_State* L = lbluetooth->fState;

	if (lbluetooth->fCallback != LUA_NOREF) {
  		luaL_unref(L, LUA_REGISTRYINDEX, lbluetooth->fCallback);
  		lbluetooth->fCallback = LUA_NOREF;
  	}
}

static void lbluetooth_callback_check(lbluetooth_t* lbluetooth, int index) 
{
	if (lbluetooth == NULL) {
		return;
	}

	lua_State* L = lbluetooth->fState;
	lbluetooth_callback_release(lbluetooth);

  	luaL_checktype(L, index, LUA_TFUNCTION);
  	lbluetooth->fCallback = luaL_ref(L, LUA_REGISTRYINDEX);
}

static void lbluetooth_callback_call(lbluetooth_t* lbluetooth, int nargs) 
{
	if (lbluetooth == NULL) {
		return;
	}

	lua_State* L = lbluetooth->fState;

  	int ref = lbluetooth->fCallback;
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
      	LOG_W("Uncaught error in lbluetooth callback: %s\n", lua_tostring(L, -1));
      	return;
    }
}

static lbluetooth_t* lbluetooth_check(lua_State* L, int index)
{
	return luaL_checkudata(L, index, VISION_BLUETOOTH);
}

// Close device handler
static int lbluetooth_close(lua_State* L)
{
	lbluetooth_t* ble = lbluetooth_check(L, 1);
	if (ble == NULL) {
		return 0;
	}

	ble->fIsClosed = TRUE;
	ble->fDeviceId  = -1;

	// 释放引用
	if (ble->fReference != LUA_NOREF) {
		luaL_unref(L, LUA_REGISTRYINDEX, ble->fReference);
		ble->fReference = LUA_NOREF;
	}

	if (ble->fHandler >= 0) {
		bt_device_close(ble);
	}

	if (ble->fThreadState != LBLUETOOTH_STATE_INIT) {
		ble->fThreadState = LBLUETOOTH_STATE_STOPING;

	} else {
		lbluetooth_release(L, ble);
	}

	return 0;
}

static int lbluetooth_gc(lua_State* L)
{
	LOG_W("gc");
	return lbluetooth_close(L);
}

//
static int lbluetooth_open(lua_State* L)
{
	int flags = luaL_optinteger(L, 1, 0);

	// 返回默认的 HCI 设备的 ID
	int deviceId = hci_get_route(NULL);

	// 1. open
	int handler = bt_device_open(deviceId);
	if (handler < 0) {
		lua_pushnil(L);
		lua_pushinteger(L, handler);
		return 2;
	}

	lbluetooth_t* ble = NULL;
	ble = lua_newuserdata(L, sizeof(*ble));
	luaL_getmetatable(L, VISION_BLUETOOTH);
	lua_setmetatable(L, -2);

	memset(ble, 0, sizeof(*ble));
	ble->fCallback 		= LUA_NOREF;
	ble->fDeviceId  	= deviceId;
	ble->fHandler 		= handler;
	ble->fReference 	= LUA_NOREF;
	ble->fState 		= L;

	// 保存 lbluetooth 对象的引用
	lua_pushvalue(L, -1);
	ble->fReference     = luaL_ref(L, LUA_REGISTRYINDEX);

	if (flags & BLE_FLAG_SCAN_ACTIVE) {
  		ble->fScanType 	= 0x01; // ACTIVE mode
	}

	queue_init(&ble->fQueue, 1024);

	return 1;
}

static int lbluetooth_release(lua_State* L, lbluetooth_t* ble)
{
	if (ble->fThreadState != LBLUETOOTH_STATE_INIT) {
		return 0;
	}

	if (ble->fCallback != LUA_NOREF) {
		lbluetooth_callback_release(ble);
		ble->fCallback = LUA_NOREF;
	}

	if (ble->fAsync != NULL) {
		LOG_W("release");

		uv_handle_t* async = (uv_handle_t*)(ble->fAsync);
		if (!uv_is_closing(async)) {
			uv_close(async, lbluetooth_async_close_callback);
		}

		ble->fAsync = NULL;
	}
	
	return 0;
}

//
static int lbluetooth_reset(lua_State* L)
{
	// 返回默认的 HCI 设备的 ID
	int deviceId = hci_get_route(NULL);
	
	int handler = bt_device_open(deviceId);
	if (handler < 0) {
		goto DONE;
	}

	// disable ble scanning
	// function(dev_id, enable, filter_dup, to)
	uint8_t enable = 0x00;
	uint8_t filter_dup = 0x01;
	hci_le_set_scan_enable(handler, enable, filter_dup, 10000);

	// close bt host
	// function(dev_id)
	hci_close_dev(handler);

DONE:
	lua_pushinteger(L, handler);
	return 1;
}

static int lbluetooth_scan(lua_State* L)
{
	int ret = -1;
	lbluetooth_t* ble = lbluetooth_check(L, 1);

	// 1. open
	int handler = ble->fHandler;
	if (handler < 0) {
		lua_pushinteger(L, ret);
		return 1;
	}

	lbluetooth_callback_check(ble, 2);

	// 2. start scan
	ret = bt_device_scan(ble);
	if (ret >= 0) {
		uv_loop_t* loop = lbluetooth_uv_loop(L);

		if (ble->fAsync == NULL) {
			ble->fAsync = malloc(sizeof(uv_async_t));
			uv_async_init(loop, ble->fAsync, lbluetooth_async_callback);
			ble->fAsync->data = ble;
		}

		if (ble->fThreadState == LBLUETOOTH_STATE_INIT) {
			ble->fThreadState = LBLUETOOTH_STATE_STARTING;
			uv_thread_create(&ble->fThread, lbluetooth_thread, ble);
		}
	}
	
	lua_pushinteger(L, ret);
	return 1;
}

static void lbluetooth_thread(void* arg)
{
	if (arg == NULL) {
		return;
	}

	lbluetooth_t* ble = (lbluetooth_t*)arg;


	if (ble->fThreadState != LBLUETOOTH_STATE_STARTING) {
		goto EXIT;
	}

	ble->fThreadState = LBLUETOOTH_STATE_RUNNING;

	int handler = ble->fHandler;

	// 4. get filter
	struct hci_filter oldFilter;
	socklen_t oldFilterSize =  sizeof(oldFilter);
	int err = getsockopt(handler, SOL_HCI, HCI_FILTER, &oldFilter, &oldFilterSize);
	if (err < 0) {
		perror("Could not get socket options");
		oldFilterSize = 0;
	}

	// 5. set filter
	struct hci_filter newFilter;
	hci_filter_clear(&newFilter);
	hci_filter_set_ptype(HCI_EVENT_PKT, &newFilter);
	hci_filter_set_event(EVT_LE_META_EVENT, &newFilter);
	err = setsockopt(handler, SOL_HCI, HCI_FILTER, &newFilter, sizeof(newFilter));
	if (err < 0) {
		perror("Could not set socket options");
	}

	char buffer[HCI_MAX_EVENT_SIZE];

	while (ble->fThreadState == LBLUETOOTH_STATE_RUNNING) {
		int ret = lbluetooth_wait_ready(handler, 1);
		if (ret < 0) {
			LOG_W("lbluetooth_thread: %d\r\n", ret);
			break;
		}

		ret = read(handler, buffer, sizeof(buffer));
		if (ret == EAGAIN || ret == EINTR) {
			continue;
		}
		//LOG_W("lbluetooth_thread: ret %d\r\n", ret);

		// 1, HCI_EVENT_HDR_SIZE = 2, subevent = 1 (4 bytes)
		// 1, uint8_t evt_type; uint8_t bdaddr_type; bdaddr_t bdaddr = 6; uint8_t length; (10 bytes)
		// last byte: RSSI

		if (ret > 12) {
			if (buffer[3] != 0x02) { // subevent
				continue;
			}

			queue_buffer_t* queue_buffer = queue_buffer_malloc(ret);
			queue_buffer->length 	= ret;
			queue_buffer->timestamp = 0;
			queue_buffer->sequence++;

			memcpy(queue_buffer->data, buffer, ret);
			if (queue_push(&ble->fQueue, queue_buffer) < 0) {
				LOG_W("The queue is full!\r\n");
				queue_buffer_free(queue_buffer);
			}

			if (ble->fAsync) {
				uv_async_send(ble->fAsync);
			}
		}
	}

EXIT:
	if (oldFilterSize > 0) {
		setsockopt(handler, SOL_HCI, HCI_FILTER, &oldFilter, oldFilterSize);
	}

	LOG_W("exit %d\r\n", ble->fThreadState);
	ble->fThreadState = LBLUETOOTH_STATE_INIT;

	if (ble->fAsync) {
		uv_async_send(ble->fAsync);
	}
}

static int lbluetooth_tostring(lua_State* L) 
{
	lbluetooth_t* ble = lbluetooth_check(L, 1);
    lua_pushfstring(L, "%s: %p", VISION_BLUETOOTH, ble);
  	return 1;
}

static int lbluetooth_wait_ready(int fd, double timeout)
{
	fd_set fds;		
	FD_ZERO(&fds);
	FD_SET(fd, &fds);		
	
	/* Timeout */
	struct timeval tv;
	tv.tv_sec  = (int)timeout;
	tv.tv_usec = 0;
	
	int ret = select(fd + 1, &fds, NULL, NULL, &tv);
	if (ret == -1) {
		return -10045;

	} else if (ret == 0) {
		return 0;
	}

	return 1;
}

static const luaL_Reg lbluetooth_methods[] = {
	{"close", 		lbluetooth_close 	},
	{"scan",  		lbluetooth_scan  	},
	{"__tostring",  lbluetooth_tostring },

	{NULL, NULL}
};

static int lbluetooth_newclass(lua_State* L) 
{
    luaL_newmetatable(L, VISION_BLUETOOTH);

    luaL_newlib(L, lbluetooth_methods);
    lua_setfield(L, -2, "__index");

    lua_pushcfunction(L, lbluetooth_gc);
    lua_setfield(L, -2, "__gc");

    lua_pop(L, 1);

    return 0;
}

static const luaL_Reg lbluetooth_functions[] = {
	{"open", 	lbluetooth_open  },
	{"reset", 	lbluetooth_reset },
	{NULL, NULL}
};

#define lua_set_number(L, name, f) \
    lua_pushnumber(L, f); \
    lua_setfield(L, -2, name);


int luaopen_lbluetooth(lua_State *L)
{
	lbluetooth_newclass(L);
	luaL_newlib(L, lbluetooth_functions);

    lua_set_number(L, "FLAG_SCAN_ACTIVE", 	0x01);


	return 1;
}
