#ifndef _MEDIA_V4L2_H
#define _MEDIA_V4L2_H

#include <linux/videodev2.h>

#define V4L2_VIDEO 			1
#define V4L_BUFFER_COUNT 	5

///////////////////////////////////////////////////////////////////////////////
// V4LContext 类

typedef struct V4LContext
{
	char  fDeviceName[255];
	
	int   fDebugFlags;
	int   fDeviceHandle;
	int   fIsStreaming;
	int   fPixelFormat;
	int   fSourceChannel;
	int   fSourceFrameRate;
	int   fSourceHeight;
	int   fSourceWidth;

	void *fCaputreBuffers[V4L_BUFFER_COUNT];
	UINT  fCaputreBufferSizes[V4L_BUFFER_COUNT];

} V4LContext;

#define V4L_FLAG_DEBUG		0x00400
#define E_NOT_INITIALIZED  	0x84400012
#define E_INALID_PARAMETER	0x84400013

///////////////////////////////////////////////////////////////////////////////
// 公开成员方法

V4LContext* V4LCreate();
BYTE* V4LGetBuffer     	(V4LContext* self, struct v4l2_buffer* v4l2Buffer);

int V4LClose			(V4LContext* self);
int V4LInit 			(V4LContext* self);
int V4LOpen 			(V4LContext* self);
int V4LStartStreaming	(V4LContext* self);
int V4LStopStreaming 	(V4LContext* self);
int V4LWaitReady 		(V4LContext* self, double timeout);
int V4LQueueBuffer 		(V4LContext* self, int index);

///////////////////////////////////////////////////////////////////////////////
// 私有成员方法

int V4LInitCamera	 	(V4LContext* self, int flags);
int V4LListFrameSizes 	(V4LContext* self, int flags);
int V4LListPixelFormats	(V4LContext* self, int flags);
int V4LMapBuffers		(V4LContext* self);
int V4LSetFrameRate  	(V4LContext* self, int flags);
int V4LSetImageFormat	(V4LContext* self, int flags);
int V4LUnmapBuffers  	(V4LContext* self);

#endif

