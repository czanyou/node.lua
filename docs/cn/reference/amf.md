# AMF

## 摘要

`Action Message Format (AMF)` 是一种简洁的二进制格式，通常用于序列化`ActionScript` object 。一旦序列化，`AMF`编码的对象可用于会话之间持久化以及检索应用程序的公共状态，或者允许两个端通过强类型数据的交换进行通信。

## AMF 0 Data Types

下方是`AMF0`的16种类型的`marker`。`marker`位占用一个字节长度，用于描述`AMF`中某种数据类型。

| marker              | value | remark                  |      |
| ------------------- | ----- | ----------------------- | ---- |
| number-marker       | 0x00  |                         |      |
| boolean-marker      | 0x01  |                         |      |
| string-marker       | 0x02  |                         |      |
| object-marker       | 0x03  |                         |      |
| movieclip-marker    | 0x04  | reserved, not supported |      |
| null-marker         | 0x05  |                         |      |
| undefined-marker    | 0x06  |                         |      |
| reference-marker    | 0x07  |                         |      |
| ecma-array-marker   | 0x08  |                         |      |
| object-end-marker   | 0x09  |                         |      |
| strict-array-marker | 0x0A  |                         |      |
| date-marker         | 0x0B  |                         |      |
| long-string-marker  | 0x0C  |                         |      |
| unsupported-marker  | 0x0D  |                         |      |
| recordset-marker    | 0x0E  | reserved, not supported |      |
| xml-document-marker | 0x0F  |                         |      |
| typed-object-marker | 0x10  |                         |      |

### 抓包分析

因为`AMF0`采用的是 `big endian (network) byte order`，所以先简单看看什么是`big endian`。

```
int val = 0x1234;

big endian:
低地址  0------->1------->2   高地址
        +--------+--------+
        |  0x12  |  0x34  |
        +--------+--------+
little endian:
        +--------+--------+
        |  0x34  |  0x12  |
        +--------+--------+
```

### Number

```
number-type = number-marker DOUBLE
```

![img](https:////upload-images.jianshu.io/upload_images/6009210-77d8d689638f2820.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/704/format/webp)

Number

如上图所示，红框内的是 Number 的 marker 为 0x00 ，紫框是 Number 的数值，为 `40 08 00 00 00 00 00 00`

看一下 rtmpdump 的实现:

```c
char *AMF_EncodeNumber(char *output, char *outend, double dVal)
{
    unsigned char *ci, *co;
    ci = (unsigned char *)&dVal;
    co = (unsigned char *)output;
    co[0] = ci[7];
    co[1] = ci[6];
    co[2] = ci[5];
    co[3] = ci[4];
    co[4] = ci[3];
    co[5] = ci[2];
    co[6] = ci[1];
    co[7] = ci[0];
}
```

### Boolean

```
boolean-type = boolean-marker U8 ; 0 is false, <> 0 is true
```

![img](https:////upload-images.jianshu.io/upload_images/6009210-24edacde032bf149.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/672/format/webp)

Boolean

如上图所示，红框内的是

Boolean 的 marker 为 0x01 ，紫框是 Boolean 的数值，为 0x01, 理论上只要非零就是 true 

rtmpdump 的实现:

```c
char * AMF_EncodeBoolean(char *output, char *outend, int bVal)
{
  *output++ = AMF_BOOLEAN;
  *output++ = bVal ? 0x01 : 0x00;
  return output;
}
```

### String

```
string-type = string-marker UTF-8
```

![img](https:////upload-images.jianshu.io/upload_images/6009210-4fbeffec1a730e57.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/597/format/webp)

String

如上图所示，红框内的是 String 的 marker 为 0x02，绿框是字符串的长度，值为 0x0008，紫框是 String 的值，为 onStatus 的 ASCII 码。

rtmpdump 的实现:

```c
char *AMF_EncodeString(char *output, char *outend, const AVal *bv)
{
 *output++ = AMF_STRING;
  output = AMF_EncodeInt16(output, outend, bv->av_len);
  memcpy(output, bv->av_val, bv->av_len);
  output += bv->av_len;
  return output;
}
```

### Object

```
object-property = (UTF-8 value-type) | (UTF-8-empty object-end-marker)
anonymous-object-type = object-marker *(object-property)
```

`Object`类型除了可以包含其他类型之外，也可以包含`Object`类型。

![img](https:////upload-images.jianshu.io/upload_images/6009210-3871d1cf3cc85862.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/654/format/webp)

Object 是以 Object-End 结束的，值为 0x000009
