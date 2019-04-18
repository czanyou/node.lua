
#define HEADERFRAME1 0xaf


static const  uint8_t jpeg_header[] = {
	0xff, 0xd8,                     // SOI
	0xff, 0xe0,                     // APP0
	0x00, 0x10,                     // APP0 header size (including
	// this field, but excluding preceding)
	0x4a, 0x46, 0x49, 0x46, 0x00,   // ID string 'JFIF\0'
	0x01, 0x01,                     // version
	0x00,                           // bits per type
	0x00, 0x00,                     // X density
	0x00, 0x00,                     // Y density
	0x00,                           // X thumbnail size
	0x00,                           // Y thumbnail size
};


static const int dht_segment_size = 420;
static const uint8_t dht_segment_head[] = { 0xFF, 0xC4, 0x01, 0xA2, 0x00 };
static const uint8_t dht_segment_frag[] = {
	0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
	0x0a, 0x0b, 0x01, 0x00, 0x03, 0x01, 0x01, 0x01, 0x01, 0x01,
	0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
};


/* Set up the standard Huffman tables (cf. JPEG standard section K.3) */
/* IMPORTANT: these are only valid for 8-bit data precision! */
const  uint8_t avpriv_mjpeg_bits_dc_luminance[17] =
{ /* 0-base */ 0, 0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0 };

const  uint8_t avpriv_mjpeg_val_dc[12] =
{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 };


const  uint8_t avpriv_mjpeg_bits_dc_chrominance[17] =
{ /* 0-base */ 0, 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0 };


const  uint8_t avpriv_mjpeg_bits_ac_luminance[17] =
{ /* 0-base */ 0, 0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7d };

const  uint8_t avpriv_mjpeg_val_ac_luminance[] =
{ 0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12,
0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07,
0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08,
0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0,
0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0a, 0x16,
0x17, 0x18, 0x19, 0x1a, 0x25, 0x26, 0x27, 0x28,
0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79,
0x7a, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98,
0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7,
0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6,
0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5,
0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4,
0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe1, 0xe2,
0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea,
0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
0xf9, 0xfa
};


const  uint8_t avpriv_mjpeg_bits_ac_chrominance[17] =
{ /* 0-base */ 0, 0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77 };


const  uint8_t avpriv_mjpeg_val_ac_chrominance[] =
{ 0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21,
0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71,
0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91,
0xa1, 0xb1, 0xc1, 0x09, 0x23, 0x33, 0x52, 0xf0,
0x15, 0x62, 0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34,
0xe1, 0x25, 0xf1, 0x17, 0x18, 0x19, 0x1a, 0x26,
0x27, 0x28, 0x29, 0x2a, 0x35, 0x36, 0x37, 0x38,
0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,
0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58,
0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68,
0x69, 0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78,
0x79, 0x7a, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96,
0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5,
0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4,
0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3,
0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2,
0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda,
0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9,
0xea, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
0xf9, 0xfa
};


static  uint8_t *append( uint8_t *buf, const uint8_t *src, int size)
{
	memcpy(buf, src, size);
	return buf + size;
}


static  uint8_t *append_dht_segment( uint8_t *buf)
{
	buf = append(buf, dht_segment_head, sizeof(dht_segment_head));
	buf = append(buf, avpriv_mjpeg_bits_dc_luminance + 1, 16);
	buf = append(buf, dht_segment_frag, sizeof(dht_segment_frag));
	buf = append(buf, avpriv_mjpeg_val_dc, 12);
	*(buf++) = 0x10;
	buf = append(buf, avpriv_mjpeg_bits_ac_luminance + 1, 16);
	buf = append(buf, avpriv_mjpeg_val_ac_luminance, 162);
	*(buf++) = 0x11;
	buf = append(buf, avpriv_mjpeg_bits_ac_chrominance + 1, 16);
	buf = append(buf, avpriv_mjpeg_val_ac_chrominance, 162);
	return buf;
}

#ifdef MEDIA_USE_JPEG_LIB

#include <jpeglib.h>

int MediaEncodeJpegYUV422(BYTE *yuvData, int imageWidth, int imageHeight, int quality, BYTE **jpegBuffer, ulong* jpegSize) 
{
	if (yuvData == NULL) {
		return -1;

	} else if (jpegBuffer == NULL || jpegSize == NULL) {
		return -1;
	}

	struct jpeg_compress_struct compressInfo;
	struct jpeg_error_mgr jerr;

	JSAMPIMAGE  buffer;
	int band, i, buf_width[3], buf_height[3], mem_size, max_line, counter;
	uint8_t *yuv[3];
	uint8_t *pSrc, *pDst;

	// YUYV -> YUV420P
	yuv[0] = yuvData; // y
	yuv[1] = yuv[0] + (imageWidth * imageHeight); // u
	yuv[2] = yuv[1] + (imageWidth * imageHeight) / 2; // v

	compressInfo.err = jpeg_std_error(&jerr);
	jpeg_create_compress(&compressInfo);
	jpeg_mem_dest(&compressInfo, jpegBuffer, jpegSize);

	compressInfo.image_width		= imageWidth;  	/* image width and height, in pixels */
	compressInfo.image_height		= imageHeight;
	compressInfo.input_components	= 3;    		/* # of color components per pixel */
	compressInfo.in_color_space		= JCS_RGB;  	/* colorspace of input image */

	jpeg_set_defaults(&compressInfo);
	jpeg_set_quality(&compressInfo, quality, TRUE );

	compressInfo.raw_data_in		= TRUE;
	compressInfo.jpeg_color_space	= JCS_YCbCr;
	compressInfo.comp_info[0].h_samp_factor = 2;
	compressInfo.comp_info[0].v_samp_factor = 1;

	jpeg_start_compress(&compressInfo, TRUE);

	buffer = (JSAMPIMAGE) (*compressInfo.mem->alloc_small) ((j_common_ptr) &compressInfo, JPOOL_IMAGE, 3 * sizeof(JSAMPARRAY));
	for (band = 0; band < 3; band++) {
		buf_width[band]  = compressInfo.comp_info[band].width_in_blocks * DCTSIZE;
		buf_height[band] = compressInfo.comp_info[band].v_samp_factor   * DCTSIZE;
		buffer[band]	 = (*compressInfo.mem->alloc_sarray) ((j_common_ptr) &compressInfo, JPOOL_IMAGE, buf_width[band], buf_height[band]);
	}

	max_line = compressInfo.max_v_samp_factor * DCTSIZE;
	for (counter = 0; compressInfo.next_scanline < compressInfo.image_height; counter++) {
		// buffer image copy.
		for (band = 0; band < 3; band++) {
			mem_size = buf_width[band];
			pDst = (uint8_t *) buffer[band][0];
			pSrc = (uint8_t *) yuv[band] + counter * buf_height[band] * buf_width[band];

			for (i = 0; i < buf_height[band]; i++) {
				memcpy(pDst, pSrc, mem_size);
				pSrc += buf_width[band];
				pDst += buf_width[band];
			}
		}
		jpeg_write_raw_data(&compressInfo, buffer, max_line);
	}

	jpeg_finish_compress (&compressInfo);
	jpeg_destroy_compress(&compressInfo);

	return 0;
}

int MediaJpegEncodeYUV420(BYTE *yuvData, int imageWidth, int imageHeight, int quality, BYTE **jpegBuffer, ulong* jpegSize) 
{
	if (yuvData == NULL) {
		return -1;

	} else if (jpegBuffer == NULL || jpegSize == NULL) {
		return -1;
	}

	BYTE* lineBuffer = (BYTE*)calloc (imageWidth * imageHeight * 3, 1);
	memset(lineBuffer, 0x80, imageWidth * imageHeight * 3);
	int i = 0;

	LOG_W("imageSize: %dx%d", imageWidth, imageHeight);

	UINT imageSize = imageWidth * imageHeight;
	UINT indexY = 0; 
	UINT indexU = 0;
	uint8_t *yuv[3];

	// YUYV -> YUV420P
	yuv[0] = lineBuffer; // y
	yuv[1] = yuv[0] + imageSize; // u
	yuv[2] = yuv[1] + imageSize / 2; // v

	BYTE* d = yuv[0];
	BYTE* s = yuvData;

	memcpy(d, s, imageSize);

	int uvWidth = imageWidth / 2;

	// u
	d = yuv[1];
	s = yuvData + imageSize;
	for (i = 0; i < imageHeight; i++) {
		memcpy(d, s, uvWidth);

		d += uvWidth;
		if ((i % 2) == 1) {
			s += uvWidth;
		}
	}

	// v
	d = yuv[2];
	s = yuvData + imageSize + imageSize / 4;
	for (i = 0; i < imageHeight; i++) {
		memcpy(d, s, uvWidth);

		d += uvWidth;
		if ((i % 2) == 1) {
			s += uvWidth;
		}
	}

	MediaEncodeJpegYUV422(lineBuffer, imageWidth, imageHeight, quality, jpegBuffer, jpegSize);

	free(lineBuffer);
	return 0;
}

int MediaJpegEncodeYUYV(BYTE *yuvData, int imageWidth, int imageHeight, int quality, BYTE **jpegBuffer, ulong* jpegSize) 
{
	if (yuvData == NULL) {
		return -1;

	} else if (jpegBuffer == NULL || jpegSize == NULL) {
		return -1;
	}

	BYTE* lineBuffer = (BYTE*)calloc (imageWidth * imageHeight * 3, 1);
	BYTE* yuyv = yuvData;
	int i = 0;

	UINT imageSize = imageWidth * imageHeight;
	UINT indexY = 0; 
	UINT indexU = 0;
	uint8_t *yuv[3];

	// YUYV -> YUV420P
	yuv[0] = lineBuffer; // y
	yuv[1] = yuv[0] + (imageWidth * imageHeight); // u
	yuv[2] = yuv[1] + (imageWidth * imageHeight) / 2; // v

	for (i = 0; i < imageSize / 2; i++) {
		yuv[0][indexY++] = yuyv[0]; // y1
		yuv[0][indexY++] = yuyv[2]; // y2
		yuv[1][indexU]	 = yuyv[1]; // u1
		yuv[2][indexU++] = yuyv[3]; // v1
		yuyv += 4;
	}

	MediaEncodeJpegYUV422(lineBuffer, imageWidth, imageHeight, quality, jpegBuffer, jpegSize);

	free(lineBuffer);
	return 0;
}


#endif // USE_LIB_JPEG
