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
#include "lutils.h"
#include "stdint.h"

int lutils_hex2int(uint8_t ch) 
{
	if (ch >= '0' && ch <= '9') {
		return ch - '0';

	} else if (ch >= 'a' && ch <= 'f') {
		return 10 + (ch - 'a');

	} else if (ch >= 'A' && ch <= 'F') {
		return 10 + (ch - 'A');
	}
	
	return -1;
}

/**
 * 把指定的 16 进制表示字符串转换为 2 进制的 BYTE 数组.
 * @param text 要转换的字符串, 如 "FE00FBCFEC"
 * @param buf  缓存区
 * @param buflen 缓存区大小
 * @return 返回成功解析的字节的个数.
 */
int lutils_hex_decode(uint8_t* buffer, size_t bufferSize, const void* data, size_t dataSize) 
{
	if (buffer == NULL || data == NULL || bufferSize == 0) {
		return -1;
	}

	const uint8_t* p = data;
	int count = 0;
	size_t i = 0;
	for (i = 0; i < bufferSize; i++) {
		if (p[0] == '\0' || p[1] == '\0' ) {
			break;
		}

		int a = lutils_hex2int(p[0]);
		int b = lutils_hex2int(p[1]);
		if (a < 0 || b < 0) {
			break;
		}

		buffer[i] = (uint8_t)((a << 4) | b);
		count++;

		p += 2;
	}

	return count;
}

int lutils_hex_encode( char* buffer, size_t bufferSize, const void* data, size_t dataSize )
{
	int ret = 0;
	if (data == NULL || dataSize == 0) {
		return ret;
	}

	char* buf = buffer;

	const uint8_t* p = (const uint8_t*)data;
	const uint8_t* end = p + dataSize;
	while (p < end) {
		sprintf(buf, "%02x", *p);
		buf += 2;
		ret += 2;
		p++;
	}

	// printf("%d/%d => %d", bufferSize, dataSize, ret);

	*buf = '\0';	
	return ret;
}
