/***
 * The content of this file or document is CONFIDENTIAL and PROPRIETARY
 * to ChengZhen(Anyou).  It is subject to the terms of a
 * License Agreement between Licensee and ChengZhen(Anyou).
 * restricting among other things, the use, reproduction, distribution
 * and transfer.  Each of the embodiments, including this information and
 * any derivative work shall retain this copyright notice.
 *
 * Copyright (c) 2014-2015 ChengZhen(Anyou). All Rights Reserved.
 *
 */
#include "media_video.h"
#include "media_comm.h"

///////////////////////////////////////////////////////////////////////////////
// Audio System

int AudioOutWriteSample(int decodeId, AudioSampleInfo* stream)
{
	return 0;
}

int AudioInGetStream(int encodeId, AudioSampleInfo* audioStream)
{
	return 0;
}

int AudioInReleaseStream(int encodeId, AudioSampleInfo* audioStream)
{
	return 0;
}

// Audio input channel
int AudioInClose(int channel)
{
	return 0;
}

int AudioInOpen(int channel, AudioSettings* settings)
{
	int format = settings->fCodecFormat;
	return -1;
}


// Audio input
int AudioInRelease()
{
	return 0;
}

int AudioInInit()
{
	return 0;
}

int AudioOutClose(int channel)
{
	return 0;
}

int AudioOutOpen(int channel, int format)
{
	return -1;
}

// Audio output
int AudioOutRelease()
{
	return 0;
}

int AudioOutInit()
{
	return 0;
}
