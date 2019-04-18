
#include "media_comm.h"
#include "media_video.h"
#include "media_queue.h"
#include "media_v4l2.h"

///////////////////////////////////////////////////////////////////////////////
// 方法实现

V4LContext* V4LCreate()
{
	V4LContext* v4l = malloc(sizeof(V4LContext));
	V4LInit(v4l);
	return v4l;
}

int V4LInit(V4LContext* self)
{
	if (self == NULL) {
		return -1;
	}
	
	self->fDeviceHandle		= -1;
	self->fIsStreaming   	= 0;
	self->fPixelFormat		= V4L2_PIX_FMT_MJPEG;
	self->fPixelFormat		= V4L2_PIX_FMT_YUYV;

	self->fSourceHeight   	= 360;
	self->fSourceWidth    	= 640;
	self->fSourceChannel    = 0;
	self->fSourceFrameRate  = 25;
	
	strcpy(self->fDeviceName, "/dev/video0");

	int i = 0;
	for (i = 0; i < V4L_BUFFER_COUNT; i++) {
		self->fCaputreBuffers[i] = NULL;
		self->fCaputreBufferSizes[i] = 0;
	}

	return 0;
}

int V4LClose(V4LContext* self)
{
	if (self == NULL) {
		return -1;
	}
	
	if (self->fIsStreaming) {
		V4LStopStreaming(self);
	}

	V4LUnmapBuffers(self);

	if (self->fDeviceHandle > 0) {
		close(self->fDeviceHandle);
		self->fDeviceHandle = -1;
	}

	return 0;
}

BYTE* V4LGetBuffer(V4LContext* self, struct v4l2_buffer* v4l2Buffer)
{
	if (self == NULL) {
		return NULL;

	} else if (v4l2Buffer == NULL) {
		return NULL;

	} else if (!self->fIsStreaming) {
		LOG_W("fIsStreaming is FALSE");
		return NULL;
	}

	v4l2Buffer->type	= V4L2_BUF_TYPE_VIDEO_CAPTURE;
	v4l2Buffer->memory  = V4L2_MEMORY_MMAP;
	int ret = ioctl(self->fDeviceHandle, VIDIOC_DQBUF, v4l2Buffer);
	if (ret != 0) {
		LOG_D("Unable to dequeue buffer (%d).\n", errno);
		return NULL;
	}

	return (BYTE*)self->fCaputreBuffers[v4l2Buffer->index];
}

int V4LInitCamera(V4LContext* self, int flags)
{
	if (self == NULL) {
		return -1;
	}

	struct v4l2_input inp;
	inp.index = 0;
	if (ioctl (self->fDeviceHandle, VIDIOC_S_INPUT, &inp) < 0) {
		LOG_E("VIDIOC_S_INPUT error!");
	}

	// Video capability
	struct v4l2_capability v4l2Capability;
	memset(&v4l2Capability, 0, sizeof(struct v4l2_capability));
	int ret = ioctl(self->fDeviceHandle, VIDIOC_QUERYCAP, &v4l2Capability);
	if (ret < 0) {
		LOG_W("Error opening device %s: unable to query device.\n",
			self->fDeviceName);
		V4LClose(self);
		return -1;
	}

	if (flags & V4L_FLAG_DEBUG) {
		printf("V4L2 Capabilities: %s, %s, 0x%x\r\n", 
			v4l2Capability.driver, v4l2Capability.card, 
			v4l2Capability.capabilities);
	}

	// Capture capabilities
	if ((v4l2Capability.capabilities & V4L2_CAP_VIDEO_CAPTURE) == 0) {
		LOG_W("Error opening device %s: video capture not supported.\n",
			self->fDeviceName);
		V4LClose(self);
		return -1;
	}

	if (!(v4l2Capability.capabilities & V4L2_CAP_STREAMING)) {
		LOG_W("%s does not support streaming i/o\n", self->fDeviceName);
		V4LClose(self);
		return -1;
	}

	if (flags & V4L_FLAG_DEBUG) {
		V4LListPixelFormats(self, 0);
		V4LListFrameSizes(self, 0);
	}

	V4LSetImageFormat(self, flags);
	V4LSetFrameRate(self, flags);

	// request & query buffers
	if (V4LMapBuffers(self) < 0) {
		V4LClose(self);
	}

	return 0;
}

int V4LListPixelFormats(V4LContext* self, int flags)
{
	struct v4l2_fmtdesc fmtdesc; 
	fmtdesc.index = 0; 
	fmtdesc.type  = V4L2_BUF_TYPE_VIDEO_CAPTURE; 

	printf("V4L2 Supported Formats:\n");

	while (ioctl(self->fDeviceHandle, VIDIOC_ENUM_FMT, &fmtdesc) != -1) {
		printf(" -  %2d. type:%d - flags:%d - pixel:0x%x %s\n", fmtdesc.index + 1, 
			fmtdesc.type, fmtdesc.flags, fmtdesc.pixelformat, fmtdesc.description);
		fmtdesc.index++;
	}
	
	return 0;
}

int V4LListFrameSizes(V4LContext* self, int flags)
{
	int i;
	struct v4l2_frmsizeenum size_enum;
	char str[16];

	size_enum.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
	size_enum.pixel_format = self->fPixelFormat;

	printf("V4L2 Supported Resolutions:\n");
	
	for (i = 0; i < 20; i++) {
		size_enum.index = i;
		if (-1 == ioctl (self->fDeviceHandle, VIDIOC_ENUM_FRAMESIZES, &size_enum)) {
			break;
		}

		sprintf(str, " - %d x %d", size_enum.discrete.width, size_enum.discrete.height);
		if (i != 0) {
			printf("%s\r\n", str);
		}
	}

	return 0;
}

int V4LMapBuffers(V4LContext* self)
{
	if (self == NULL) {
		return -1;
	} 

	int fd = self->fDeviceHandle;
	if (fd <= 0) {
		return -1;
	}

	// Request buffers 
	// 初始化内存映射或者用户指针 IO, 内存映射缓冲区由设备内存分配而且必须在应用程序
	// 地址空间分配之前由 ioctl 分配。
	struct v4l2_requestbuffers	v4l2RequestBuffers;
	memset(&v4l2RequestBuffers, 0, sizeof(struct v4l2_requestbuffers));
	v4l2RequestBuffers.count	= V4L_BUFFER_COUNT; // count 是所需 buffer 数量
	v4l2RequestBuffers.type		= V4L2_BUF_TYPE_VIDEO_CAPTURE; // 用 type 来区分流或者缓冲区
	v4l2RequestBuffers.memory	= V4L2_MEMORY_MMAP;	// memory 必须设置为 v4l2_MEMORY_MMAP
	int ret = ioctl(fd, VIDIOC_REQBUFS, &v4l2RequestBuffers);
	if (ret < 0) {
		LOG_W("Unable to allocate buffers: %d.\n", errno);
		return -1;
	}

	struct v4l2_buffer v4l2Buffer;
	int i = 0;

	// Query and map buffers 
	for (i = 0; i < V4L_BUFFER_COUNT; i++) {
		memset(&v4l2Buffer, 0, sizeof(struct v4l2_buffer));
		v4l2Buffer.index	= i;
		v4l2Buffer.type		= V4L2_BUF_TYPE_VIDEO_CAPTURE;
		v4l2Buffer.memory	= V4L2_MEMORY_MMAP;
		ret = ioctl(fd, VIDIOC_QUERYBUF, &v4l2Buffer);
		if (ret < 0) {
			LOG_W("Unable to query buffer (%d).\n", errno);
			return -1;
		}

		int length = v4l2Buffer.length;
		void* buffer = mmap(0, length, PROT_READ | PROT_WRITE, 
			MAP_SHARED, fd, v4l2Buffer.m.offset);
		if (buffer == MAP_FAILED) {
			LOG_W("Unable to map buffer (%d) (%d)\n", length, errno);
			return -1;
		}

		self->fCaputreBuffers[i]    = buffer;
		self->fCaputreBufferSizes[i] = v4l2Buffer.length;
	}

	return 0;
}
int V4LOpen(V4LContext* self)
{
	if (self == NULL) {
		return -1;

	} else if (self->fSourceWidth <= 0 || self->fSourceHeight <= 0) {
		LOG_W("Invalid video image size");
		return -1;
	}

	if (self->fDeviceHandle > 0) {
		V4LClose(self);
	}

	int ret = 0;

	// Open video device
	self->fDeviceHandle = open(self->fDeviceName, O_RDWR | O_NONBLOCK, 0);
	if (self->fDeviceHandle == -1) {
		LOG_W("Error opening V4L interface (%s) %d\n", self->fDeviceName, errno);
		V4LClose(self);
		return -1;
	}

	LOG_W("%s\r\n", self->fDeviceName);

	int flags = self->fDebugFlags;
	if (flags & V4L_FLAG_DEBUG) {
		LOG_W("V4L2 Device ID: %d\r\n", self->fDeviceHandle);
	}

	if (V4LInitCamera(self, flags) < 0) {
		LOG_W("V4L2 init failed! exit fatal! \n");
		V4LClose(self);
		return -1;
	}

	return 0;
}

int V4LQueueBuffer(V4LContext* self, int index)
{
	if (self == NULL) {
		return -1;

	} else if (self->fDeviceHandle <= 0) {
		return -1;
	}

	struct v4l2_buffer v4l2Buffer;
	memset(&v4l2Buffer, 0, sizeof(v4l2Buffer));
	v4l2Buffer.type		= V4L2_BUF_TYPE_VIDEO_CAPTURE;
	v4l2Buffer.memory 	= V4L2_MEMORY_MMAP;
	v4l2Buffer.index    = index;

	int ret = ioctl(self->fDeviceHandle, VIDIOC_QBUF, &v4l2Buffer);
	if (ret != 0) {
		//LOG_W("Unable to release buffer %d (%d).\n", index, errno);
	}

	return ret;
}


int V4LSetFrameRate(V4LContext* self, int flags)
{
	if (self == NULL) {
		return -1;
	} 

	int fd = self->fDeviceHandle;
	if (fd <= 0) {
		return -1;
	}

	// Set framerate 
	struct v4l2_streamparm streamParams;
	memset(&streamParams, 0, sizeof(struct v4l2_streamparm));
	int ret = ioctl(fd, VIDIOC_G_PARM, &streamParams);

	streamParams.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
	streamParams.parm.capture.timeperframe.numerator	= 1;
	streamParams.parm.capture.timeperframe.denominator	= self->fSourceFrameRate;
	ret = ioctl(fd, VIDIOC_S_PARM, &streamParams);
	if (ret < 0) {
		printf("V4LSetFrameRate: %d %d\r\n", ret, streamParams.parm.capture.timeperframe.denominator);
	}

	ioctl(fd, VIDIOC_G_PARM, &streamParams);

	if (flags & V4L_FLAG_DEBUG) {
		printf("V4L2 Image Framerate: %dfps\r\n", streamParams.parm.capture.timeperframe.denominator);
	}

	return ret;
}

int V4LSetImageFormat(V4LContext* self, int flags)
{
	if (self == NULL) {
		return -1;
	}

	int fd = self->fDeviceHandle;
	if (fd <= 0) {
		return -1;
	}

	int videoWidth  = self->fSourceWidth;
	int videoHeight = self->fSourceHeight;
	int pixelFormat = self->fPixelFormat;

	// Set video pixel format
	struct v4l2_format	v4l2Format;
	memset(&v4l2Format, 0, sizeof(struct v4l2_format));
	int ret = ioctl(fd, VIDIOC_G_FMT, &v4l2Format);

	v4l2Format.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
	v4l2Format.fmt.pix.width		= videoWidth;
	v4l2Format.fmt.pix.height		= videoHeight;
	v4l2Format.fmt.pix.pixelformat	= pixelFormat;
	v4l2Format.fmt.pix.field		= V4L2_FIELD_ANY;
	ret = ioctl(fd, VIDIOC_S_FMT, &v4l2Format);
	if (ret < 0) {
		pixelFormat = V4L2_PIX_FMT_YUV420;
		v4l2Format.fmt.pix.pixelformat	= pixelFormat;

		ret = ioctl(fd, VIDIOC_S_FMT, &v4l2Format);
		if (ret < 0) {
			LOG_E("V4L2 unable to set format: %d.\n", errno);
			V4LClose(self);
			return -1;
		}
	}

	self->fPixelFormat = pixelFormat;

	// Set image size
	if ((v4l2Format.fmt.pix.width  != (unsigned int)videoWidth) ||
		(v4l2Format.fmt.pix.height != (unsigned int)videoHeight)) {
		printf("V4L2 asked unavailable size: %d x %d \n",
			v4l2Format.fmt.pix.width, v4l2Format.fmt.pix.height);
		self->fSourceWidth  = v4l2Format.fmt.pix.width;
		self->fSourceHeight = v4l2Format.fmt.pix.height;
	}

	if (flags & V4L_FLAG_DEBUG) {
		printf("V4L2 Image Size: %d x %d\n", v4l2Format.fmt.pix.width, v4l2Format.fmt.pix.height);
		printf("V4L2 Image Format: 0x%x\n", v4l2Format.fmt.pix.pixelformat);
	}

	return ret;
}

int V4LStartStreaming(V4LContext* self)
{
	if (self == NULL) {
		return -1;
	}

	int fd = self->fDeviceHandle;
	if (fd <= 0) {
		return -1;
	}

	if (self->fIsStreaming) {
		return 0;
	}

	// Queue the buffers. 
	int i = 0;
	for (i = 0; i < V4L_BUFFER_COUNT; ++i) {
		int ret = V4LQueueBuffer(self, i);
		if (ret < 0) {
			LOG_W("%d: Unable to queue buffer (%d).\n", i, errno);
		}
	}

	int type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
	int ret = ioctl(fd, VIDIOC_STREAMON, &type);
	if (ret < 0) {
		LOG_W("Unable to start capture: %d.\n", errno);
		return ret;
	}

	self->fIsStreaming = 1;

	return 0;
}

int V4LStopStreaming(V4LContext* self)
{
	if (self == NULL) {
		return -1;
	}
	
	if (!self->fIsStreaming) {
		return 0;
	}

	int fd = self->fDeviceHandle;
	if (fd <= 0) {
		self->fIsStreaming = 0;
		return -1;
	}

	int type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
	int ret = ioctl(fd, VIDIOC_STREAMOFF, &type);
	if (ret < 0) {
		LOG_W("Unable to stop capture: %d.\n", errno);
		return ret;
	}

	self->fIsStreaming = 0;
	
	return 0;
}

int V4LUnmapBuffers(V4LContext* self)
{
	uint32_t i = 0;
	for (i = 0; i < V4L_BUFFER_COUNT; i++) {
		void* buffer  = self->fCaputreBuffers[i];
		uint32_t size = self->fCaputreBufferSizes[i];
		self->fCaputreBuffers[i] 	= NULL;
		self->fCaputreBufferSizes[i] = 0;

		if (buffer && size > 0) {
			munmap(buffer, size);
		}
	}

	return 0;	
}

int V4LWaitReady(V4LContext* self, double timeout)
{
	int fd = self->fDeviceHandle;

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

