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

//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// Video Process

int VideoProcessGroupBind()
{
	return 0;
}

int VideoProcessGroupStop(int vpssGroup)
{
	return 0;
}

int VideoProcessChannelDisable(int vpssGroup, int vpssChannel)
{
	return 0;

}

int VideoProcessOutputBind(int GrpChn, int VpssGrp, int VpssChn)
{
	return 0;

}

int VideoProcessMemConfig()
{
	return 0;

}

//_____________________________________________________________________________
///////////////////////////////////////////////////////////////////////////////
// Video Encode Channel

int VideoEncodeClose(int channel)
{
	return 0;
}

int VideoEncodeGetAttributes(int channel, VideoSettings* settings)
{
	return 0;
}

int VideoEncodeGetStream(int channel, struct VideoSampleInfo* sampleInfo)
{
	return 0;
}

int VideoEncodeNextStream(int channel, BOOL isBlocking)
{
	return 0;
}

int VideoEncodeOpen(int channel, struct VideoSettings* settings) 
{
	return 0;
}

int VideoEncodeBind(int channel, int groupId)
{
	return 0;
}

int VideoEncodeReleaseStream(int channel, struct VideoSampleInfo* sampleInfo)
{
	return 0;
}

int VideoEncodeRenewStream(int channel) 
{ 
	return 0;
}

int VideoEncodeSetAttributes(int channel, struct VideoSettings* settings) 
{
	return 0;
}

int VideoEncodeSetCrop(int groupId, int l, int t, int w, int h)
{
	return 0;

}

int VideoEncodeStart(int channel, int flags) 
{ 
	return 0;
}

int VideoEncodeStop(int channel)
{
	return 0;
}

//______________________________________________________________________________
////////////////////////////////////////////////////////////////////////////////
// Video Input

int  VideoInSetAttributes(int index);

int VideoInRelease() 
{
	return 0;
}

int VideoInInit(UINT flags) 
{
	return 0;
}

int VideoInSetAttributes(int index) 
{
	return 0;
}

//______________________________________________________________________________
////////////////////////////////////////////////////////////////////////////////
// Video Input Channel

int VideoInClose(int channel) 
{
	return 0;
}

int VideoInGetFrameRate( int channel )
{
	return 0;
}

int VideoInOpen( int channel, int width, int height, int flags ) 
{
	return 0;
}

/** */
int VideoInSetFrameRate( int channel, UINT frameRate )
{
	return 0;
}

//______________________________________________________________________________
////////////////////////////////////////////////////////////////////////////////
// Overlay

int VideoOverlayClose(int regionId)
{
	return 0;
}

int VideoOverlayOpen(int regionId, int width, int height)
{
	return 0;
}

int VideoOverlaySetBitmap(int regionId, int width, int height, BYTE* bitmapData)
{
	return 0;
}
