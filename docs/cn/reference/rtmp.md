# RTMP - 实时传输消息协议

## 名词解释

- Chunk Stream ID
- Message Stream ID



## 握手

```sequence
客户端->服务端: C0 Version (8bits = 0x03)
客户端->服务端: C1 RANDOM (1528)
服务端->客户端: S0 Version (8bits = 0x03)
服务端->客户端: S1 RANDOM (1528)
客户端->服务端: C2 ACK RANDOM ECHO (1528)
服务端->客户端: S2 ACK RANDOM ECHO (1528)
客户端->客户端: 完成握手
```

## 数据块流 

```c
 +--------------+----------------+--------------------+--------------+
 | Basic Header | Message Header | Extended Timestamp |  Chunk Data  |
 +--------------+----------------+--------------------+--------------+
 |                                                    |
 |<------------------- Chunk Header ----------------->|
                            Chunk Format

```



同一个 RTMP 连接会复用一个或多个数据块流 ，每个流都有不同的 ID. 每个数据块通过流 ID 来区分属于哪个流。

- 基本头 Basic Header  (1~3 字节)
- 消息头 Message Header (0,3,7 或 11 字节)
- 扩展时间戳 Extended Timestamp (0 或 4 字节)
- 块数据 Chunk Data (可变长度)

### 基本头

公共定义

- fmt (2 bits) 4 种消息头格式

基本头类型 （共 3 种):

- CS ID (6 bits) 2 - 63 流 ID (Chunk Stream ID)

```c
   0 1 2 3 4 5 6 7
  +-+-+-+-+-+-+-+-+
  |fmt|   cs id   |
  +-+-+-+-+-+-+-+-+
 Chunk basic header 1
```

- CS Ext8 ID  (8 bits) 64 - X 流 ID (CS ID = 0)

```c
0                      1
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |fmt|      0    |  cs id - 64   |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      Chunk basic header 2
```

- CS Ext16 ID (16 bits) 64 - X 流 ID (CS ID = 1)

```c
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |fmt|         1 |          cs id - 64           |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
             Chunk basic header 3
```

### 消息头

#### Type 0

```c
  0                   1                   2                   3
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                          timestamp            | message length|
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |      message length (cont)    |message type id| msg stream id |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |          message stream id (cont)             |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                Chunk Message Header - Type 0
```

`Message Header`占用`11`个字节， 在`chunk stream`的开始的第一个`chunk`的时候必须采用这种格式。

• **timestamp**：`3`个字节，因此它最多能表示到`16777215=0xFFFFFF=2^24-1`, 当它的值超过这个最大值时，这三个字节都置为1，实际的`timestamp`会转存到`Extended Timestamp`字段中，接受端在判断`timestamp`字段24个位都为1时就会去`Extended timestamp`中解析实际的时间戳。

• **message length**：`3`个字节，表示实际发送的消息的数据如音频帧、视频帧等数据的长度，单位是字节。注意这里是Message的长度，也就是chunk属于的Message的总数据长度，而不是chunk本身Data的数据的长度。

• **message type id**：`1`个字节，表示实际发送的数据的类型，如`8`代表音频数据、`9`代表视频数据。

• **message stream id**：`4`个字节，表示该chunk所在的流的`ID`，和`Basic Header`的`CSID`一样，它采用小端存储的方式

#### Type 1

```c
  0                   1                   2                   3
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                          timestamp            | message length|
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |      message length (cont)    |message type id|  
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ 
                Chunk Message Header - Type 1
```

`Message Header`占用7个字节，省去了表示`msg stream id`的4个字节，表示此`chunk`和上一次发的`chunk`所在的流相同。

• **timestamp delta**：3个字节，注意这里和格式0时不同，存储的是和上一个chunk的时间差。类似上面提到的`timestamp`，当它的值超过3个字节所能表示的最大值时，三个字节都置为1，实际的时间戳差值就会转存到`Extended Timestamp`字段中，接受端在判断`timestamp delta`字段24个位都为1时就会去`Extended timestamp`中解析时机的与上次时间戳的差值。

#### Type 2

```c
  0                   1                   2     
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ 
 |                          timestamp            |  
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ 
          Chunk Message Header - Type 2

```

`Message Header`占用3个字节，相对于格式1，又省去了表示消息长度的3个字节和表示消息类型的1个字节，表示此chunk和上一次发送的chunk所在的流、消息的长度和消息的类型都相同。余下的这三个字节表示`timestamp delta`，使用同格式1。

#### Type 3

表示不存在消息头

### **Extended Timestamp（扩展时间戳）**

在`chunk`中会有时间戳`timestamp`和时间戳差`timestamp delta`，并且它们不会同时存在，只有这两者之一大于3个字节能表示的最大数值`0xFFFFFF＝16777215`时，才会用这个字段来表示真正的时间戳，否则这个字段为0。

扩展时间戳占`4`个字节，能表示的最大数值就是`0xFFFFFFFF＝4294967295`。当扩展时间戳启用时，`timestamp`字段或者`timestamp delta`要全置为`1`，表示应该去扩展时间戳字段来提取真正的时间戳或者时间戳差。注意扩展时间戳存储的是完整值，而不是减去时间戳或者时间戳差的值。

### **Chunk Data（块数据）**

 用户层面上真正想要发送的与协议无关的数据，长度在(0, chunkSize]之间, `chunk size`默认为`128`字节。

#### • **Chunk Size**:

RTMP是按照`chunk size`进行分块，`chunk size` 指的是 `chunk`的`payload`部分的大小，不包括`chunk basic header` 和 `chunk message header`长度。客户端和服务器端各自维护了两个`chunk size`, 分别是自身分块的`chunk size` 和 对端 的`chunk size`, 默认的这两个`chunk size`都是128字节。通过向对端发送`set chunk size` 消息可以告知对方更改了 `chunk size`的大小。

#### • **Chunk Type**:

RTMP消息分成的`Chunk`有`4`种类型，可以通过 `chunk basic header`的高两位(`fmt`)指定，一般在拆包的时候会把第一个RTMP消息打包成以格式`0`开始的`chunk`，之后的包打包成格式`3` 类型的`chunk`，这是最简单的实现。

如果第二个`message`和第一个`message`的`message stream ID` 相同，并且第二个`message`的长度也大于了`chunk size`，那么该如何拆包？当时查了很多资料，都没有介绍。后来看了一些源码，如 `SRS`，`FFMPEG`中的实现，发现第二个`message`可以拆成`Type 1`类型一个`chunk`， `message`剩余的部分拆成`Type 3`类型的`chunk`。`FFMPEG`中就是这么做的。

## 协议控制消息

### Set Chunk Size (1)

```c
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|0| chunk size (31 bits)                                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
Payload for the ‘Set Chunk Size’ protocol message
```

### Abort Message (2)

```c
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|       chunk stream id (32 bits)                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
Payload for the ‘Abort Message’ protocol message
```

### Acknowledgement (3)

```c
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|       sequence number (4 bytes)                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
Payload for the ‘Acknowledgement’ protocol message
```



### Window Acknowledgement Size (5)

```c
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|       Acknowledgement Window size (4 bytes)                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
Payload for the ‘Window Acknowledgement Size’ protocol message
```



### Set Peer Bandwidth (6)

```c
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 Acknowledgement Window size                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Limit Type    |
+-+-+-+-+-+-+-+-+
Payload for the ‘Set Peer Bandwidth’ protocol message
```

- 0 Hard
- 1 Soft
- 2 Dynamic

## RTMP 消息格式

### 消息格式

#### 消息头

```c
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Message Type  | Payload length                                |
| (1 byte)      | (3 bytes)                                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Timestamp (4 bytes)                                           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Message Stream ID (3 bytes)                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
Message Header
```



#### 消息体

### 用户控制消息

```c
+------------------------------+-------------------------
| Event Type (16 bits) | Event Data
+------------------------------+-------------------------
Payload for the ‘User Control’ protocol message
```

- 0 |Stream Begin + 4-byte  stream ID
- 1 | Stream EOF + 4-byte  stream ID
- 2 | StreamDry + 4-byte  stream ID
- 3 | SetBuffer  Length  + 4-byte  stream ID + 4 bytes buffer length in milliseconds.
- 4 | StreamIs  Recorded + 4 bytes stream ID
- 6 | PingRequest + 4-byte timestamp
- 7 | PingResponse + 4-byte timestamp

## RTMP 命令消息

```c
 +----------------+---------+---------------------------------------+
 |  Field Name    |   Type  |               Description             |
 +--------------- +---------+---------------------------------------+
 |   Command Name | String  | Name of the command. Set to "connect".|
 +----------------+---------+---------------------------------------+
 | Transaction ID | Number  |            Always set to 1.           |
 +----------------+---------+---------------------------------------+
 | Command Object | Object  |  Command information object which has |
 |                |         |           the name-value pairs.       |
 +----------------+---------+---------------------------------------+
 | Optional User  | Object  |       Any optional information        |
 |   Arguments    |         |                                       |
 +----------------+---------+---------------------------------------+
```



### 消息类型

#### Command Message

- ID = 20 (0x14) or 17 (0x11)

#### Data Message

- ID =  18 (0x12) or 15 (0x0F)

#### Shared Object Message (19, 16)

#### Audio Message (8)

#### Video Message (9)

#### Aggregate Message (22)

#### User Control Message Events

### 命令类型

#### NetConnection

##### connect

- Command Name {string} `connect`
- Transaction ID {number} 1
- Command Object {object}
- Optional User Arguments {object}

response:

- Command Name {string} `_result`
- Transaction ID {number} 1
- Properties {object}
- Information {object}

##### call

- Procedure Name

##### close

##### createStream

- Command Name {string} `createStream`
- Transaction ID {number} 
- Command Object {object} 

response:

- Command Name  {string} `_result`
- Transaction ID {number} 
- Command Object {object} 
- Stream ID {number} 

#### NetStream

##### play

- Command Name {string} play
- Transaction ID {number} 0
- Command Object {Null}
- Stream Name {string} 
- Start {number}
- Duration {number}
- Reset {boolean}

##### play2

##### deleteStream

##### closeStream

##### receiveAudio

##### receiveVideo

##### publish

- Command Name {string} publish
- Transaction ID {number} 0 
- Command Object {Null} null
- Publishing Name {string}
- Publishing Type {string} live/record/append

##### seek

##### pause

## 示例

### 发布视频流

```sequence
客户端->服务端: Handshaking
客户端->客户端: 完成握手
客户端->服务端: connect
服务端->客户端: Window Acknowledge Size
服务端->客户端: Set Peer BandWidth
客户端->服务端: Window Acknowledge Size
服务端->客户端: StreamBegin
服务端->客户端: connect response
客户端->客户端: 创建流
客户端->服务端: createStream
服务端->客户端: createStream response
客户端->客户端: 发布
客户端->服务端: publish
服务端->客户端: StreamBegin
客户端->服务端: Metadata
客户端->服务端: Audio Data
客户端->服务端: Video Data
客户端->客户端: 直到完成

```







