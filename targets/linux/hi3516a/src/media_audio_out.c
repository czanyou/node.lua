
///////////////////////////////////////////////////////////////////////////////
// Audio decode

int AudioOutCloseDecode(int channel, int decodeId)
{
	// HI_MPI_ADEC_ClearChnBuf(decodeId)
	return HI_MPI_ADEC_DestroyChn(decodeId);
}

int AudioOutWriteSample(int decodeId, AudioSampleInfo* streamInfo)
{
	if (streamInfo == NULL) {
		return -1;
	}

	//LOG_D("%d (%d)\r\n", fSequence, len);
	HI_BOOL isBlock = HI_FALSE ;

	AUDIO_STREAM_S audioStream;
	memset(&audioStream, 0, sizeof(audioStream));
	audioStream.pStream		 = streamInfo->fPacketData;
	audioStream.u32Len		 = streamInfo->fPacketSize;
	audioStream.u32Seq		 = streamInfo->fSequence;
	audioStream.u64TimeStamp = streamInfo->fSampleTime;

	// 发送音频流到解码通道
	return HI_MPI_ADEC_SendStream(decodeId, &audioStream, isBlock);
}

int AudioOutOpenDecode(int channel, int decodeId, int format)
{
	// 初始化音频解码通道
	ADEC_CHN_ATTR_S attributes;    
	//attributes.enMode 	= ADEC_MODE_STREAM;	// ADEC_MODE_PACK;	 /* pack mode or stream mode ? */
	attributes.enMode 		= ADEC_MODE_PACK;	// ADEC_MODE_STREAM; /* pack mode or stream mode ? */
	attributes.u32BufSize 	= 5;				// 0 ~ 50, 以帧为单位

	if (format == 1) {
		attributes.enType = PT_G711A;
		ADEC_ATTR_G711_S options;
		attributes.pValue = &options;

	} else if (format == 2) {
		attributes.enType = PT_G711U;
		ADEC_ATTR_G711_S options;
		attributes.pValue = &options;

	} else {
		attributes.enType = PT_LPCM;
		ADEC_ATTR_LPCM_S options;
		attributes.pValue = &options;
	}

	/* Create audio decode channel */
	int ret = HI_MPI_ADEC_CreateChn(decodeId, &attributes);
	if (ret < 0) {
		return ret;
	}

	if (channel >= 0) {
		int err = AudioOutBind(channel, -1, decodeId);
		LOG_D("AudioOutBind: 0x%x", err);
	}

	return ret;
}

int AudioOutBind(int channel, int inChannel, int decodeId)
{
	LOG_D("AudioOutBind: %d,%d,%d", channel, inChannel, decodeId);

	MPP_CHN_S srcChannel;

	if (inChannel >= 0) {
		srcChannel.enModId	 = HI_ID_AI;
		srcChannel.s32DevId	 = AUDIO_DEVICE_0;
		srcChannel.s32ChnId	 = inChannel;

	} else if (decodeId >= 0) {
		srcChannel.enModId	 = HI_ID_ADEC;
		srcChannel.s32DevId	 = 0;
		srcChannel.s32ChnId	 = decodeId;

	} else {
		return -1;
	}

	MPP_CHN_S destChannel;
	destChannel.enModId	 = HI_ID_AO;
	destChannel.s32DevId = AUDIO_DEVICE_0;
	destChannel.s32ChnId = channel;

	return HI_MPI_SYS_Bind(&srcChannel, &destChannel);
}

int AudioOutClose(int channel)
{
	AudioOutCloseDecode(channel, channel);

	// HI_MPI_AO_ClearChnBuf(AUDIO_DEVICE_0, channel);
	return HI_MPI_AO_DisableChn(AUDIO_DEVICE_0, channel);
}

int AudioOutInit()
{
	AudioOutSetAttributes(0);
	return HI_MPI_AO_Enable(AUDIO_DEVICE_0);
}

int AudioOutOpen(int channel, int format)
{
	int ret = HI_MPI_AO_EnableChn(AUDIO_DEVICE_0, channel);
	if (ret < 0) {
		return ret;
	}

	if (format >= 0) {
		AudioOutOpenDecode(channel, channel, format);
	}

	return HI_MPI_AO_GetFd(AUDIO_DEVICE_0, channel);
}

// Audio output
int AudioOutRelease()
{
	return HI_MPI_AO_Disable(AUDIO_DEVICE_0);
}

int AudioOutSetAttributes(int format)
{
	AIO_ATTR_S attributes;
	attributes.enBitwidth		= AUDIO_BIT_WIDTH_16;	// should equal to DA TLV320 
	attributes.enSamplerate		= AUDIO_SAMPLE_RATE_8000;
	attributes.enSoundmode		= AUDIO_SOUND_MODE_MONO;
	attributes.enWorkmode		= AIO_MODE_I2S_SLAVE;  // HI3515
	attributes.u32ChnCnt		= 2;
	attributes.u32ClkSel		= 0;
	attributes.u32EXFlag		= 1;
	attributes.u32FrmNum		= 20;
	attributes.u32PtNumPerFrm	= 320;

	return HI_MPI_AO_SetPubAttr(AUDIO_DEVICE_0, &attributes);
}
