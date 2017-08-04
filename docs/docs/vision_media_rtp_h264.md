
# H.264 视频 RTP 负载格式

[TOC]

本文本描述的是如何将 H.264 打包成 RTP 包的方式，关于 H.264 打包成 TS 流并通过 RTP 包传输的方式请参考 `TS 流 RTP 负载格式`

## 目录



## 网络抽象层单元类型 (NALU)

NALU 头由一个字节组成, 它的语法如下:

```
  +---------------+
  |0|1|2|3|4|5|6|7|
  +-+-+-+-+-+-+-+-+
  |F|NRI|  Type   |
  +---------------+
```

- F: 1 个比特.

    forbidden_zero_bit. 在 H.264 规范中规定了这一位必须为 0.

- NRI: 2 个比特.

    nal_ref_idc. 取 00 ~ 11, 似乎指示这个 NALU 的重要性, 如 00 的 NALU 解码器可以丢弃它而不影响图像的回放. 不过一般情况下不太关心这个属性.

- Type: 5 个比特.

    nal_unit_type. 这个 NALU 单元的类型. 简述如下:

```
  0     没有定义
  1-23  NAL单元  单个 NAL 单元包.
  24    STAP-A   单一时间的组合包
  25    STAP-B   单一时间的组合包
  26    MTAP16   多个时间的组合包
  27    MTAP24   多个时间的组合包
  28    FU-A     分片的单元
  29    FU-B     分片的单元
  30-31 没有定义
```

## 打包模式

下面是 RFC 3550 中规定的 RTP 头的结构.

```
       0                   1                   2                   3
       0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |V=2|P|X|  CC   |M|     PT      |       sequence number         |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                           timestamp                           |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |           synchronization source (SSRC) identifier            |
      +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
      |            contributing source (CSRC) identifiers             |
      |                             ....                              |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

- 负载类型 Payload type (PT): 7 bits
- 序列号 Sequence number (SN): 16 bits
- 时间戳 Timestamp: 32 bits
  
H.264 Payload 格式定义了三种不同的基本的负载(Payload)结构. 接收端可能通过 RTP Payload 的第一个字节来识别它们. 这一个字节类似 NALU 头的格式, 而这个头结构的 NAL 单元类型字段则指出了代表的是哪一种结构,  

这个字节的结构如下, 可以看出它和 H.264 的 NALU 头结构是一样的. 

```
      +---------------+
      |0|1|2|3|4|5|6|7|
      +-+-+-+-+-+-+-+-+
      |F|NRI|  Type   |
      +---------------+
```
 
  字段 Type: 这个 RTP payload 中 NAL 单元的类型. 这个字段和 H.264 中类型字段的区别是, 当 type 的值为 24 ~ 31 表示这是一个特别格式的 NAL 单元, 而 H.264 中, 只取 1~23 是有效的值. 

```
  24    STAP-A   单一时间的组合包
  25    STAP-B   单一时间的组合包
  26    MTAP16   多个时间的组合包
  27    MTAP24   多个时间的组合包
  28    FU-A     分片的单元
  29    FU-B     分片的单元
  30-31 没有定义
```

可能的结构类型分别有: 

- 1. 单一 NAL 单元模式 
    即一个 RTP 包仅由一个完整的 NALU 组成. 这种情况下 RTP NAL 头类型字段和原始的 H.264的 NALU 头类型字段是一样的.

- 2. 组合封包模式
    即可能是由多个 NAL 单元组成一个 RTP 包. 分别有4种组合方式: STAP-A, STAP-B, MTAP16, MTAP24. 那么这里的类型值分别是 24, 25, 26 以及 27.

- 3. 分片封包模式
    用于把一个 NALU 单元封装成多个 RTP 包. 存在两种类型 FU-A 和 FU-B. 类型值分别是 28 和 29.


### 单一 NAL 单元模式

对于 NALU 的长度小于 MTU 大小的包, 一般采用单一 NAL 单元模式. 对于一个原始的 H.264 NALU 单元常由 [Start Code] [NALU Header] [NALU Payload] 三部分组成, 其中 Start Code 用于标示这是一个  

NALU 单元的开始, 必须是 "00 00 00 01" 或 "00 00 01", NALU 头仅一个字节, 其后都是 NALU 单元内容.

打包时去除 "00 00 01" 或 "00 00 00 01" 的开始码, 把其他数据封包的 RTP 包即可. 

```
       0                   1                   2                   3
       0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |F|NRI|  type   |                                               |
      +-+-+-+-+-+-+-+-+                                               |
      |                                                               |
      |               Bytes 2..n of a Single NAL unit                 |
      |                                                               |
      |                               +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                               :...OPTIONAL RTP padding        |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

如有一个 H.264 的 NALU 是这样的: 

    [00 00 00 01 67 42 A0 1E 23 56 0E 2F ... ]    

 这是一个序列参数集 NAL 单元. [00 00 00 01] 是四个字节的开始码, 67 是 NALU 头, 42 开始的数据是 NALU 内容.

封装成 RTP 包将如下: 

    [ RTP Header ] [ 67 42 A0 1E 23 56 0E 2F ]    

即只要去掉 4 个字节的开始码就可以了. 

### 组合封包模式

其次, 当 NALU 的长度特别小时, 可以把几个 NALU 单元封在一个 RTP 包中. 

```
  
       0                   1                   2                   3
       0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                          RTP Header                           |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |STAP-A NAL HDR |         NALU 1 Size           | NALU 1 HDR    |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                         NALU 1 Data                           |
      :                                                               :
      +               +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |               | NALU 2 Size                   | NALU 2 HDR    |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                         NALU 2 Data                           |
      :                                                               :
      |                               +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                               :...OPTIONAL RTP padding        |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

```

### Fragmentation Units (FUs).

而当 NALU 的长度超过 MTU 时, 就必须对 NALU 单元进行分片封包. 也称为 Fragmentation Units (FUs). 

```
       0                   1                   2                   3
       0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      | FU indicator  |   FU header   |                               |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               |
      |                                                               |
      |                         FU payload                            |
      |                                                               |
      |                               +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                               :...OPTIONAL RTP padding        |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

      Figure 14.  RTP payload format for FU-A
```


The FU indicator octet has the following format: 


```
      +---------------+
      |0|1|2|3|4|5|6|7|
      +-+-+-+-+-+-+-+-+
      |F|NRI|  Type   |
      +---------------+
```


The FU header has the following format: 

```
      +---------------+
      |0|1|2|3|4|5|6|7|
      +-+-+-+-+-+-+-+-+
      |S|E|R|  Type   |
      +---------------+
```

如有一个 H.264 的 NALU 是这样的: 

```
[00 00 00 01 67 42 A0 1E 23 56 0E 2F ... ] 
[00 00 00 01 67 42 A0 1E 23 56 0E 2F ... ] 
```

这是一个序列参数集 NAL 单元. [00 00 00 01] 是四个字节的开始码, 67 是 NALU 头, 42 开始的数据是 NALU 内容. 

封装成 RTP 包可能如下: 

```
[ RTP Header ] [78, STAP-A NAL HDR, 一个字节 ] [长度, 两个字节] [ 67 42 A0 1E 23 56 0E 2F ...] [长度, 两个字节] [ 67 42 A0 1E 23 56 0E 2F... ] 
```

## SDP 参数

下面描述了如何在 SDP 中表示一个 H.264 流: 

- "m=" 行中的媒体名必须是 "video"
- "a=rtpmap" 行中的编码名称必须是 "H264".
- "a=rtpmap" 行中的时钟频率必须是 90000.
- 其他参数都包括在 "a=fmtp" 行中.

如: 

```
  m=video 49170 RTP/AVP 98
  a=rtpmap:98 H264/90000
  a=fmtp:98 profile-level-id=42A01E; sprop-parameter-sets=Z0IACpZTBYmI,aMljiA==
```
  
下面介绍一些常用的参数.

### packetization-mode:

表示支持的封包模式. 
  
- 当 packetization-mode 的值为 0 时或不存在时, 必须使用单一 NALU 单元模式.
- 当 packetization-mode 的值为 1 时必须使用非交错(non-interleaved)封包模式.
- 当 packetization-mode 的值为 2 时必须使用交错(interleaved)封包模式.
  
这个参数不可以取其他的值.

### sprop-parameter-sets:

这个参数可以用于传输 H.264 的序列参数集和图像参数 NAL 单元. 这个参数的值采用 Base64 进行编码. 不同的参数集间用","号隔开.
  
### profile-level-id:

这个参数用于指示 H.264 流的 profile 类型和级别. 由 Base16(十六进制) 表示的 3 个字节. 第一个字节表示 H.264 的 Profile 类型, 第三个字节表示 H.264 的 Profile 级别.
  
### max-mbps:

这个参数的值是一个整型, 指出了每一秒最大的宏块处理速度.

## 参考代码

```c

/** 发送指定的 NALU 单元. */ 
int GEPlayback::SendNaluPacket( BYTE* sliceData, int sliceSize, BOOL isEnd, 
BOOL isVideo, int type, time_t pts, INT64 timestamp ) 
{ 
    // NALU 小于最大 RTP 包大小的情况 
    if (sliceSize < 1350) { 
        return SendPacket(sliceData, sliceSize, isEnd, TRUE, type, pts, timestamp); 
    } 

    // 如果一个 NALU 大于最大的 RTP 包的大小, 则需要把它进行分片后打包发送 
    BYTE buffer[1500]; 

    BYTE nalHeader = sliceData[0]; // NALU 头 
    BYTE* data = sliceData + 1; 
    int leftover = sliceSize - 1; 
    BOOL isStart = TRUE; 

    while (leftover > 0) { 
        int size = MIN(1350, leftover); 
        isEnd = (size == leftover); 

        // 构建 FU 头 
        buffer[0] = (nalHeader & 0x60) | 28; // FU indicator 
        buffer[1] = (nalHeader & 0x1f); // FU header 
        if (isStart) { 
            buffer[1] |= 0x80; 
        } 

        if (isEnd) { 
            buffer[1] |= 0x40; 
        } 

        memcpy(buffer + 2, data, size); 
        SendPacket(buffer, size + 2, isEnd, TRUE, type, pts, timestamp); 

        leftover -= size; 
        data += size; 
        isStart = FALSE; 
    } 

    return sliceSize; 
} 
```

