# FLV

## FLV 文件格式

FLV 包括文件头 (File Header) 和文件体 (File Body) 两部分。文件结构如图所示: 

> FLV 文件 = FLV 文件头 + [tag1 + tag内容1] + [tag2 + tag内容2] + ... + ... + [tagN + tag内容 N]

## FLV 文件头

FLV 文件头部分记录了 FLV 的类型、版本等信息，是 FLV 的开头，一般都差不多占 9bytes。具体格式如下: 

1. 文件标识 (3Bytes): 总是为 `FLV`, 0x46 0x4c 0x56
2. 版本 (1Bytes): 目前为 0x01
3. 流信息 (1Byte): 文件的标志位说明。前 5 位保留，必须为 0；第 6 位为音频标志: 1 表示有音频；第七位保留，总是为 0； 第 8 位为视频标志: 1 表示有视频
4. Header 长度 (4Bytes): 整个文件头的长度，一般为 9 (版本为0x01时)。即 `0x00000009`

## FLV 文件体

文件体由一系列的 Tag 组成。其中，每个Tag 前面还包含了 Previous Tag Size 字段，表示前面一个 Tag 的大小。Tag 的类型可以是视频、音频和 Script，每个 Tag 只能包含以上三种类型的数据中的一种。

| **Field**          | **Type** | **Comment**                                            |
| ------------------ | -------- | ------------------------------------------------------ |
| PreviousTagSize0   | UINT32   | 总是为 0                                               |
| Tag1               | FLV-TAG  | 第一个 TAG                                             |
| PreviousTagSize1   | UINT32   | 前一个 TAG的大小， 包括 TAG 头在内，等于 DataSize + 11 |
| Tag2               | FLVTAG   | 第二个 TAG                                             |
| ...                | ...      | ...                                                    |
| PreviousTagSizeN-1 | UINT32   | 前一个 TAG 的大小， 包括 TAG 头在内                    |
| TagN               | FLVTAG   | 最后一个 TAG                                           |
| PreviousTagSizeN   | UINT32   | 最后一个 TAG 的大小， 包括 TAG 头在内                  |

`FLV header` 之后, 就是 `FLV File Body`.

### FLV Tag

每个 Tag 也是由两部分组成的: Tag Header 和 Tag Data。Tag Header 里存放的是当前 Tag 的类型、数据区 (Tag Data) 长度等信息，具体如下: 

- Tag 类型 (1): 0x08: 音频; 0x09: 视频; 0x12: 脚本; 其他: 保留
- 数据区长度 (3): 数据区的长度
- 时间戳 (3): 整数，单位是毫秒。对于脚本型的 tag 总是 0 (CTS) 
- 时间戳扩展 (1): 将时间戳扩展为 4bytes，代表高 8 位。很少用到
- StreamsID (3): 总是 0
- 数据区 (由数据区长度决定): 数据实体

### 音频 Tag

音频 Tag 开始的第 1 个字节包含了音频数据的参数信息，从第 2 个字节开始为音频流数据。如图为音频 Tag 结构: 

![这里写图片描述](https://img-blog.csdn.net/20160902175428670)

第 1 个字节的前 4 位的数值表示了音频编码类型，第 5-6 位的数值表示音频采样率，第 7 位表示音频采样精度，第8 位表示音频类型。具体格式如下: 

**StreamID**之后的数据就表示是 **AudioTagHeader**，**AudioTagHeader **结构如下: 

| **Field**     | **Type**                 | **Comment**                                                  |
| ------------- | ------------------------ | ------------------------------------------------------------ |
| SoundFormat   | UB [4]                   | Format of SoundData. The following values are defined:<br/> 0 = Linear PCM, platform endian<br/> 1 = ADPCM<br/> 2 = MP3<br/> 3 = Linear PCM, little endian<br/> 4 = Nellymoser 16 kHz mono<br/> 5 = Nellymoser 8 kHz mono<br/> 6 = Nellymoser<br/> 7 = G.711 A-law logarithmic PCM<br/> 8 = G.711 mu-law logarithmic PCM<br/> 9 = reserved<br/> 10 = AAC<br/> 11 = Speex<br/> 14 = MP3 8 kHz<br/> 15 = Device-specific sound<br/> Formats 7, 8, 14, and 15 are reserved. AAC is supported in Flash Player 9,0,115,0 and higher. Speex is supported in Flash Player 10 and higher. |
| SoundRate     | UB [2]                   | Sampling rate. The following values are defined:<br/> 0 = 5.5 kHz<br/> 1 = 11 kHz<br/> 2 = 22 kHz<br/> 3 = 44 kHz |
| SoundSize     | UB [1]                   | Size of each audio sample. This parameter only pertains to uncompressed formats. Compressed formats always decode to 16 bits internally.<br/> 0 = 8-bit samples<br/> 1 = 16-bit samples |
| SoundType     | UB [1]                   | Mono or stereo sound<br/> 0 = Mono sound<br/> 1 = Stereo sound         |
| AACPacketType | IF SoundFormat == 10 UI8 | The following values are defined:<br/> 0 = AAC sequence header<br/> 1 = AAC raw |

从上图可以看出，FLV 封装格式并不支持 48KHz 的采样率。

### 视频 Tag

视频 Tag 也用开始的第 1 个字节包含视频数据的参数信息，从第 2 个字节为视频流数据。如图为视频 Tag  结构:  
![这里写图片描述](https://img-blog.csdn.net/20160902180045206)

第 1 个字节的前 4 位的数值表示帧类型，后 4 位的数值表示视频编码类型。具体格式如下: 

前 4 位为帧类型 Frame Type

| 值   | 类型                                              |
| ---- | ------------------------------------------------- |
| 1    | keyframe (for AVC, a seekable frame) 关键帧       |
| 2    | inter frame (for AVC, a non-seekable frame)       |
| 3    | disposable inter frame (H.263 only)               |
| 4    | generated keyframe (reserved for server use only) |
| 5    | video info/command frame                          |

后 4 位为编码 ID (CodecID)

| 值   | 类型                       |
| ---- | -------------------------- |
| 1    | JPEG (currently unused)    |
| 2    | Sorenson H.263             |
| 3    | Screen video               |
| 4    | On2 VP6                    |
| 5    | On2 VP6 with alpha channel |
| 6    | Screen video version 2     |
| 7    | AVC                        |

VideoData 为数据具体内容: 

- 如果 CodecID=2，为 H263VideoPacket； 
- 如果 CodecID=3，为 ScreenVideopacket； 
- 如果 CodecID=4，为 VP6FLVVideoPacket； 
- 如果 CodecID=5，为 VP6FLVAlphaVideoPacket； 
- 如果 CodecID=6，为 ScreenV2VideoPacket； 
- 如果 CodecID=7，为 AVCVideoPacket；

#### AVCVideoPacket 格式

AVCVideoPacket 同样包括 Packet Header 和 Packet Body 两部分:  
即 AVCVideoPacket Format:  

```
| AVCPacketType(8)| CompostionTime(24) | Data | 
```

AVCPacketType 为包的类型:  

- 如果 AVCPacketType = 0x00，为 AVCSequence Header； 
- 如果 AVCPacketType = 0x01，为 AVC NALU； 
- 如果 AVCPacketType = 0x02，为 AVC end of sequence 

CompositionTime 为相对时间戳:  

- 如果 AVCPacketType=0x01， 为相对时间戳； 
- 其它，均为 0； 

Data 为负载数据:  

- 如果AVCPacketType = 0x00，为 AVCDecorderConfigurationRecord； 
- 如果AVCPacketType = 0x01，为 NALUs； 
- 如果AVCPacketType = 0x02，为空。 

#### AVCDecorderConfigurationRecord 格式

AVCDecorderConfigurationRecord 包括文件的信息。 
具体格式如下:  

```
| cfgVersion(8) 
| avcProfile(8) 
| profileCompatibility(8) 
| avcLevel(8) 
| reserved(6) 
| lengthSizeMinusOne(2) 
| reserved(3) 
| numOfSPS(5) 
| spsLength(16) 
| sps(n) 
| numOfPPS(8) 
| ppsLength(16) 
| pps(n) |
```

### Script Tag

该类型 Tag 又通常被称为 Metadata Tag，会放一些关于 FLV 视频和音频的元数据信息如: duration、width、height 等。通常该类型 Tag 会跟在 File Header 后面作为第一个 Tag 出现，而且只有一个。结构如图所示: 

![这里写图片描述](https://img-blog.csdn.net/20160904163957698)

#### 第一个 AMF 包

第 1 个字节表示 AMF 包类型，常见的数据类型如下: 

```
0 = Number type
1 = Boolean type
2 = String type
3 = Object type
4 = MovieClip type
5 = Null type
6 = Undefined type
7 = Reference type
8 = ECMA array type
10 = Strict array type
11 = Date type
12 = Long string type
```

FLV 文件中，第一个字节一般总是 0x02，表示字符串。第 2-3 个字节为 UI16 类型值，标识字符串的长度，一般总是 0x000A (“onMetaData”长度) 。后面字节为具体的字符串，一般总为 “onMetaData” (6F,6E,4D,65,74,61,44,61,74,61) 。

#### 第二个 AMF 包

第 1 个字节表示 AMF 包类型，一般总是 0x08，表示数组。第 2-5 个字节为 UINT32 类型值，表示数组元素的个数。后面即为各数组元素的封装，数组元素为元素名称和值组成的对。常见的数组元素如下表:  

| **Property Name** | **Type** | **Comment**                                                  |
| ----------------- | -------- | ------------------------------------------------------------ |
| audiocodecid      | Number   | Audio codec ID used in the file (see E.4.2.1 for available SoundFormat values) |
| audiodatarate     | Number   | Audio bit rate in kilobits per second                        |
| audiodelay        | Number   | Delay introduced by the audio codec in seconds               |
| audiosamplerate   | Number   | Frequency at which the audio stream is replayed              |
| audiosamplesize   | Number   | Resolution of a single audio sample                          |
| canSeekToEnd      | Boolean  | Indicating the last video frame is a key frame               |
| creationdate      | String   | Creation date and time                                       |
| duration          | Number   | Total duration of the file in seconds                        |
| filesize          | Number   | Total size of the file in bytes                              |
| framerate         | Number   | Number of frames per second                                  |
| height            | Number   | Height of the video in pixels                                |
| stereo            | Boolean  | Indicating stereo audio                                      |
| videocodecid      | Number   | Video codec ID used in the file (see E.4.3.1 for available CodecID values) |
| videodatarate     | Number   | Video bit rate in kilobits per second                        |
| width             | Number   | Width of the video in pixels                                 |

这里面的 duration、filesize、视频的 width、height 等这些信息对我们来说很有用.

## FLV 数据分析

第一帧报文: 

![img](http://images2015.cnblogs.com/blog/487115/201608/487115-20160812094947343-1830194860.png)

1) 0x46 4c 56字符FLV头，固定字符
2) 0x01: 版本，目前为固定字符
3) 0x05: 01表示有视频，04表示有音频，05表示既有视频又有音频。
4) 0x00 00 00 09: flv包头长度

5) 0x00 00 00 00 : 这个是第1帧的PreviousTagSize0 (前帧长度)，因为是第一帧，所以肯定是0；
6) 0x08: 帧开头第一字节: 0x08 表示音频，0x09 表示视频，0x12 表示脚本信息，放一些关于 FLV 视频和音频的参数信息，如 duration、width、height 等。
7) 0x00 00 04: 帧 payload 长度: 因为音频第一帧是 ASC，所以只有 4 字节。
8) 0x00 00 00 00: timestamp，时间戳
9) 0x00 00 00: streamid，流 ID
10) 0xAF 00 13 90: 

音频 payload: 0xaf00 开头的后面是 asc flag, 0xaf01 开头的后面是真正的音频数据

0x13 90, 也就是 `0b0001 0011 1001 0000`, 
ASC flag 格式: xxxx xyyy yzzz z000
x字符:  aac type，类型 2 表示 AAC-LC，5 是SBR, 29 是 ps，5 和 29 比较特殊 asc flag 的长度会变成 4；
y字符:  sample rate, 采样率, 7 表示 22050 采样率
z字符:  通道数，2 是双通道

11) 0x 00 00 00 0F 这个还是 PreviousTagSize1，上一帧长度 15 bytes
12) 0x09 视频类型，新的一帧
13) 0x00 00 22 视频帧 payload长度
14) 0x00 00 0a 00 

时间戳: 这个地方有个大坑，顺序是: a[3] a[0] a[1] a[2]，最后一位是最高位。

15) 0x00 00 00 streamid, 流 ID。
16) 0x 17 00 视频帧开头2字节: 

- 0x17 00: 表示内容是 SPS 和 PPS
- 0x17 01: 表示内容是 I-FRAME
- 0x27:    表示内容是 P-FRAME

17) 

```
0000002bh: 17 00 00 00 00 01 42 C0 1F FF E1 00 0E 67 42 C0 ; ......B??.gB?
0000003bh: 1F 8C 8D 40 F0 28 90 0F 08 84 6A 01 00 04 68 CE ; .實@??.刯...h?
0000004bh: 3C 80 ; <€

```

第 12, 13 字节: 0x00 0E 是 spslen，也就是 14 字节长度
跳过 14 字节后，0x01 是 pps 开始的标识，跳过它。

`0x00 04` 是 ppslen，也就是 4 个字节，最后 `0x68 ce 3c 80` 就是 pps。

前 4 位为帧类型 `Frame Type`

| 值   | 类型                                              |
| ---- | ------------------------------------------------- |
| 1    | keyframe (for AVC, a seekable frame) 关键帧       |
| 2    | inter frame (for AVC, a non-seekable frame)       |
| 3    | disposable inter frame (H.263 only)               |
| 4    | generated keyframe (reserved for server use only) |
| 5    | video info/command frame                          |

后 4 位为编码 `ID (CodecID)`

| 值   | 类型                       |
| ---- | -------------------------- |
| 1    | JPEG (currently unused)    |
| 2    | Sorenson H.263             |
| 3    | Screen video               |
| 4    | On2 VP6                    |
| 5    | On2 VP6 with alpha channel |
| 6    | Screen video version 2     |
| 7    | AVC                        |

### 特殊情况

视频的格式 (**CodecID**) 是 AVC (H.264) 的话，VideoTagHeader 会多出4个字节的信息，AVCPacketType 和 CompositionTime。

- AVCPacketType 占 1 个字节

| 值   | 类型                                                         |
| ---- | ------------------------------------------------------------ |
| 0    | AVCDecoderConfigurationRecord (AVC sequence header)           |
| 1    | AVC NALU                                                     |
| 2    | AVC end of sequence (lower level NALU sequence ender is not required or supported) |

**AVCDecoderConfigurationRecord** 包含着是 H.264 解码相关比较重要的 **sps** 和 **pps** 信息，在给 AVC 解码器送数据流之前一定要把 sps 和 pps 信息送出，否则的话解码器不能正常解码。而且在解码器 stop 之后再次 start 之前，如 seek、快进快退状态切换等，都需要重新送一遍 sps 和 pps 的信息. AVCDecoderConfigurationRecord 在 FLV 文件中一般情况也是**出现1次**，也就是 **第一个video tag**.

- CompositionTime 占 3 个字节

| 条件              | 值                      |
| ----------------- | ----------------------- |
| AVCPacketType ==1 | Composition time offset |
| AVCPacketType !=1 | 0                       |

我们看第一个 video tag，也就是前面那张图。我们看到 AVCPacketType =0。而后面三个字节也是0。说明这个 tag 记录的是 AVCDecoderConfigurationRecord。包含 sps 和 pps 数据。
再看到第二个video tag

![img](https://upload-images.jianshu.io/upload_images/2111324-81454e31e2208b83.png)

看到 AVCPacketType =1，而后面三个字节为 000043。这是一个视频帧数据。

### sps 和 pps

前面我们提到第一个 video tag 一般存放的是 sps 和 pps。这里我们具体解析下 sps 和 pps 内容。先看下存储的格式: 

```c
0x01+sps[1]+sps[2]+sps[3]+0xFF+0xE1+sps size+sps+01+pps size+pps
```

我们看到 。

- sps[1]=`0x64`
- sps[2]=`00`
- sps[3]=`0D`
- sps size=`0x001B`=27

跳过 27 个字节后，是`0x01`

- pps size = `0x0005`=118

跳过 5 个字节，就到了 back-pointers。

### 视频帧数据

解析出 sps 和 pps tag 后，后面的 video tag 就是真正的视频数据内容了

