#ifndef LBLUETOOTH_LUA_H
#define LBLUETOOTH_LUA_H

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/sysinfo.h>
#include <unistd.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "bluetooth/bluetooth.h"
#include "bluetooth/hci.h"
#include "bluetooth/hci_lib.h"

#include "uv.h"
#include "buffer_queue.h"

/* Unofficial value, might still change */
#define LE_LINK						0x80

#define FLAGS_AD_TYPE 				0x01
#define FLAGS_LIMITED_MODE_BIT 		0x01
#define FLAGS_GENERAL_MODE_BIT 		0x02

#define EIR_FLAGS                   0x01  /* flags */
#define EIR_UUID16_SOME             0x02  /* 16-bit UUID, more available */
#define EIR_UUID16_ALL              0x03  /* 16-bit UUID, all listed */
#define EIR_UUID32_SOME             0x04  /* 32-bit UUID, more available */
#define EIR_UUID32_ALL              0x05  /* 32-bit UUID, all listed */
#define EIR_UUID128_SOME            0x06  /* 128-bit UUID, more available */
#define EIR_UUID128_ALL             0x07  /* 128-bit UUID, all listed */
#define EIR_NAME_SHORT              0x08  /* shortened local name */
#define EIR_NAME_COMPLETE           0x09  /* complete local name */
#define EIR_TX_POWER                0x0A  /* transmit power level */
#define EIR_DEVICE_ID               0x10  /* device ID */


// Public Device Addrss：公有设备地址是设备所特有的并且是不可改变的。类似网络设备的MAC地址，
// 它的长度为48位。由两部分组成：company_assigned(24bit) + company_id(24bit)
// Ramdom Device Address：随机设备地址（私有设备地址），它也是48位。组成如下所示：
// hash(24bit) + random(24bit)
#define OWN_TYPE					LE_PUBLIC_ADDRESS

// 对应上图的内容解释如下：
// 1.接受任何设备的扫描请求或连接请求。（Value：0x00）
// 2.仅仅接受白名单中的特定设备的扫描请求，但是接受任何设备的连接请求。（Value：0x01）
// 3.接受任何设备的扫描请求，但仅仅接受白名单中的特定设备的连接请求。（Value：0x02）
// 4.仅仅接受白名单中的特定设备的扫描请求和连接请求。（Value：0x03）
// 5.保留
#define FILTER_POLICY				0x00

// 如果这两个参数的值相同，表示连续不停地扫描
#define SCAN_INTERVAL				htobs(0x0010) // 指示两次扫描之间的间隔
#define SCAN_WINDOW					htobs(0x0010) // 指示一次扫描的时间（即 RX 打开的时间）

#define BLE_FLAG_SCAN_ACTIVE  		0x01

// BLE的通信包括两个主要部分：advertising（广告）和connecting（连接）。
// 广告数据包长度最多47个字节，由以下部分组成：
//	1 byte preamble（1字节做报头）
//  4 byte access address（4字节做地址）
//  39 bytes advertising channel PDU（39个字节用于PDU数据包）
//  3 bytes CRC（3个字节用于CRC数据校验）
// 对于广告通信信道，地址部分永远都是 0x8E89BED6 。对于其它数据信道，地址部分由不同的连接决定。

// 返回的PDU数据也拥有自己的数据报头（2个字节：声明有效载荷数据的长度和类型——设备是否支持连接等等）
// 和当前有效载荷数据（最多37个字节）。
// 最终，有效载荷数据中的头6个字节是设备的MAC地址，所以实际信息数据最高可占31个字节。


// 那么一个iBeacon设备的BLE广告数据是如何组成的？以下是Apple修正的数据格式，
// 整理如下（也可以参考 这里 ）：

// 02 01 06 1A FF 4C 00 02 15: iBeacon prefix (fixed)
// B9 40 7F 30 F5 F8 46 6E AF F9 25 55 6B 57 FE 6D: proximity UUID (here: Estimote’s fixed UUID)
// 00 49: major
// 00 0A: minor
// C5: 2’s complement of measured TX power

// 广播数据和扫描回应数据，它们的长度都不能超过31个字节（0 ~ 31），数据的格式必须满足下图的要求，
// 可以包含多个AD数据段，但是每个AD数据段必须由“Length：Data”组成，其中Length占用1个octet，
// Data部分占用Length个字节，所以一个AD段的长度为：Length+1。格式图如下所示：
// | 1      | 1    | Length - 2 | ...
// | Length | Type |  Data ...  |
//

typedef struct lbluetooth_s
{
	int  fDeviceId;
	int  fHandler;
	int  fCallback;
	int  fThreadState;
	int  fIsClosed;
	int  fScanType;
	int  fReference;

	queue_t fQueue;

	lua_State*  fState;
	uv_async_t* fAsync;		/* async handler */
	uv_thread_t fThread;

} lbluetooth_t;

typedef enum lbluetooth_state_s 
{
	LBLUETOOTH_STATE_INIT = 0,
	LBLUETOOTH_STATE_STARTING, 
	LBLUETOOTH_STATE_RUNNING,
	LBLUETOOTH_STATE_STOPING,
	LBLUETOOTH_STATE_STOPPED
} lbluetooth_state;


#endif // LBLUETOOTH_LUA_H
