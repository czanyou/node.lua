
#ifdef MEDIA_USE_AW_ENCODER

#include "aw/vencoder.h"

typedef struct VideoEncodeSettings
{
   	int bitrate;
   	int framerate;
   	int keyInterval;
   	int qMin;
   	int qMax;
   	int sourceWidth;
   	int sourceHeight;
   	int destWidth;
   	int destHeight;
   	VENC_CODEC_TYPE codecType;

} VideoEncodeSettings;

typedef struct VencContext
{
    VideoEncoder* 	videoEncoder;
	VencBaseConfig 	baseConfig;
	VencHeaderData  parametersData;
	VencH264Param   h264Param;

} VencContext;

int VencReleaseContext(void* context);

BYTE* VencGetParametersData(void* context, int* size) {
	VencContext *vencContext = (VencContext*)context;

	VencHeaderData* data = &(vencContext->parametersData);
    if (size) {
        *size = data->nLength;
    }
	return data->pBuffer;
}

void* VencCreate(VideoEncodeSettings* settings) {
    if (settings == NULL) {
        return NULL;
    }

    VencContext *vencContext = (VencContext *)malloc(sizeof(VencContext));
    memset(vencContext, 0, sizeof(VencContext));

    // 
    VideoEncoder* videoEncoder = NULL;
    videoEncoder = VideoEncCreate(settings->codecType);
    printf( "Creating Encode: %p, type=%d\n", videoEncoder, settings->codecType);
    vencContext->videoEncoder = videoEncoder;

    if (settings->codecType == VENC_CODEC_H264) {
        // init h264 parameters
        VencH264Param h264Param;
        h264Param.bEntropyCodingCABAC = 1;
        h264Param.nBitrate                  = settings->bitrate; /* bps */
        h264Param.nFramerate                = settings->framerate; /* framerate */
        h264Param.nCodingMode               = VENC_FRAME_CODING;
        h264Param.nMaxKeyInterval           = settings->keyInterval;
        h264Param.sProfileLevel.nProfile    = VENC_H264ProfileMain;
        h264Param.sProfileLevel.nLevel      = VENC_H264Level31;
        h264Param.sQPRange.nMinqp           = settings->qMin;
        h264Param.sQPRange.nMaxqp           = settings->qMax;
        VideoEncSetParameter(videoEncoder, VENC_IndexParamH264Param, &h264Param);
        vencContext->h264Param    = h264Param;

        //int filter = 0;
        //VideoEncSetParameter(videoEncoder, VENC_IndexParamIfilter, &filter);

        LOG_W("init h264 parameters");

        int rotation = 180; // degree
        int ret = VideoEncSetParameter(videoEncoder, VENC_IndexParamRotation, &rotation);
        LOG_W("VideoEncSetParameter: %d", ret);
      
    } else if (settings->codecType == VENC_CODEC_JPEG) {
        int quality = settings->qMax;
        int ret = VideoEncSetParameter(videoEncoder, VENC_IndexParamJpegQuality, &quality);
        LOG_W("init JPEG parameters: %d", ret);

        EXIFInfo exifInfo;
        memset(&exifInfo, 0, sizeof(exifInfo));
        VideoEncSetParameter(videoEncoder, VENC_IndexParamJpegExifInfo, &exifInfo);
    }

    // base config
    VencBaseConfig baseConfig;
    memset(&baseConfig, 0 ,sizeof(VencBaseConfig));
    baseConfig.nInputWidth  = settings->sourceWidth;
    baseConfig.nInputHeight = settings->sourceHeight;
    baseConfig.nStride      = settings->sourceWidth;
    baseConfig.nDstWidth    = settings->destWidth;
    baseConfig.nDstHeight   = settings->destHeight;
    baseConfig.eInputFormat = VENC_PIXEL_YUV420P;
    vencContext->baseConfig = baseConfig;
    int ret = VideoEncInit(videoEncoder, &baseConfig);
    LOG_W("VideoEncInit %d", ret);

    // 
    if (settings->codecType == VENC_CODEC_H264) {
        VideoEncGetParameter(videoEncoder, VENC_IndexParamH264SPSPPS, &vencContext->parametersData);
        LOG_W("get h264 parameters %d");
    }

    // buffer settings
    VencAllocateBufferParam bufferParam;
    memset(&bufferParam, 0, sizeof(VencAllocateBufferParam));
    bufferParam.nSizeY = baseConfig.nInputWidth * baseConfig.nInputHeight;
    bufferParam.nSizeC = baseConfig.nInputWidth * baseConfig.nInputHeight / 2;
    bufferParam.nBufferNum = 4;
    AllocInputBuffer(videoEncoder, &bufferParam);

    LOG_W("init buffer parameters");

    return vencContext;
}

static int VencGetInputBuffer(void* context, VencInputBuffer* inputBuffer) {
	VencContext *vencContext = (VencContext*)context;
	VideoEncoder* videoEncoder = vencContext->videoEncoder;

    if (videoEncoder == NULL || inputBuffer == NULL) {
        return -1;
    }

	memset(inputBuffer, 0, sizeof(VencInputBuffer));
	int ret = GetOneAllocInputBuffer(videoEncoder, inputBuffer);
	if (ret < 0) {
		printf("Alloc input buffer is full , skip this frame");
		return ret;
	}

	return 0;
}

static int VencEncodeInputFrame(void* context, VencInputBuffer* inputBuffer) {
	VencContext *vencContext = (VencContext*)context;
	VideoEncoder* videoEncoder = vencContext->videoEncoder;
    if (videoEncoder == NULL || inputBuffer == NULL) {
        return -1;
    }

    int ret = 0;

    #if 0
	int ret = FlushCacheAllocInputBuffer(videoEncoder, inputBuffer);
	if (ret < 0) {
	    printf("Flush alloc error %d.\n", ret);
	}
    #endif

	ret = AddOneInputBuffer(videoEncoder, inputBuffer);
	if (ret < 0) {
	    printf("Add one input buffer %d\n", ret);
        return ret;
	}

	ret = VideoEncodeOneFrame(videoEncoder);
    if (ret < 0) {
        printf("VideoEncodeOneFrame %d\n", ret);
        return ret;
    }

	AlreadyUsedInputBuffer(videoEncoder, inputBuffer);
	ReturnOneAllocInputBuffer(videoEncoder, inputBuffer);

	return ret;
}

static int VencGetOutputFrame(void* context, VencOutputBuffer* outputBuffer) {
	VencContext *vencContext = (VencContext*)context;
	VideoEncoder* videoEncoder = vencContext->videoEncoder;
    if (videoEncoder == NULL || outputBuffer == NULL) {
        return -1;
    }

	memset(outputBuffer, 0, sizeof(VencOutputBuffer));
	return GetOneBitstreamFrame(videoEncoder, outputBuffer);
}

int VencReleaseContext(void* context) 
{
    VencContext *vencContext = (VencContext*)context;
    if (vencContext == NULL) {
        return -1;
    }

    VideoEncoder* videoEncoder = vencContext->videoEncoder;
    vencContext->videoEncoder = NULL;

    if (videoEncoder) {
        ReleaseAllocInputBuffer(videoEncoder);
        VideoEncUnInit(videoEncoder);
        VideoEncDestroy(videoEncoder);
    }

    free(vencContext);
    vencContext = NULL;

    return 0;
}

static int VencReleaseOutputFrame(void* context, VencOutputBuffer* outputBuffer) 
{
	VencContext *vencContext = (VencContext*)context;
	VideoEncoder* videoEncoder = vencContext->videoEncoder;
    if (videoEncoder == NULL) {
        return -1;
    }

	return FreeOneBitStreamFrame(videoEncoder, outputBuffer);
}

queue_buffer_t* VencEncodeFrame(void* context, BYTE* frameData, int frameSize)
{
    if (context == NULL) {
        return NULL;

    } else if (frameData == NULL || frameSize <= 0) {
        return NULL;
    }

    VencContext *vencContext = (VencContext*)context;
    VideoEncoder* videoEncoder = vencContext->videoEncoder;
    if (videoEncoder == NULL) {
        return NULL;
    }

    VencInputBuffer inputBuffer;
    if (VencGetInputBuffer(context, &inputBuffer) < 0) {
        return NULL;
    }

    int videoWidth  = vencContext->baseConfig.nInputWidth;
    int videoHeight = vencContext->baseConfig.nInputHeight;

    // encode

#if 1
    int ySize  = videoWidth * videoHeight;
    BYTE* s = frameData + ySize - videoWidth;
    BYTE* d = inputBuffer.pAddrVirY;

    int i = 0;
    for (i = 0; i < videoHeight; i++) {
        memcpy(d, s, videoWidth);
        s -= videoWidth;
        d += videoWidth;
    }


    int uvWidth  = videoWidth  / 2;
    int uvHeight = videoHeight / 2;

    s = frameData + ySize + ySize / 4 - uvWidth;
    d = inputBuffer.pAddrVirC;
    for (i = 0; i < uvHeight; i++) {
        memcpy(d, s, uvWidth);
        s -= uvWidth;
        d += uvWidth;
    }

    s = frameData + ySize + ySize / 2 - uvWidth;
    d = inputBuffer.pAddrVirC + ySize / 4;
    for (i = 0; i < uvHeight; i++) {
        memcpy(d, s, uvWidth);
        s -= uvWidth;
        d += uvWidth;
    }    

#else
    int ySize  = videoWidth * videoHeight;
    memcpy(inputBuffer.pAddrVirY, frameData, ySize);

    int uvSize = videoWidth * videoHeight / 2;
    memcpy(inputBuffer.pAddrVirC, frameData + ySize, uvSize);
#endif

    VencEncodeInputFrame(context, &inputBuffer);

    // output
    VencOutputBuffer outputBuffer;
    if (VencGetOutputFrame(context, &outputBuffer) < 0) {
        return NULL;
    }

    int   spsSize = 0;
    BYTE* spsData = NULL;

    if (outputBuffer.nFlag & VENC_BUFFERFLAG_KEYFRAME) {
        spsData = VencGetParametersData(context, &spsSize);
    }

    UINT  imageSize = 0;
    imageSize += spsSize;
    imageSize += outputBuffer.nSize0;
    imageSize += outputBuffer.nSize1;
    if (imageSize <= 0) {
        return NULL;
    }

    queue_buffer_t* buffer = queue_buffer_malloc(imageSize);

    BYTE* p = (BYTE*)buffer->data;
    if (spsData && spsSize > 0) {
        memcpy(p, spsData, spsSize);
        p += spsSize;

        buffer->flags = FLAG_IS_SYNC; // sync
    }   

    if (outputBuffer.pData0 && outputBuffer.nSize0 > 0) {
        memcpy(p, outputBuffer.pData0, outputBuffer.nSize0);
        p += outputBuffer.nSize0;
    }

    if (outputBuffer.pData1 && outputBuffer.nSize1 > 0) {
        memcpy(p, outputBuffer.pData1, outputBuffer.nSize1);
        p += outputBuffer.nSize1;
    }

    buffer->timestamp = MediaGetTickCount();
    buffer->length    = imageSize;

    VencReleaseOutputFrame(context, &outputBuffer);

    return buffer;
}

#endif
