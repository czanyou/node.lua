# H.264 视频 RTP 负载格式

[TOC]

本文本描述的是如何将 H.264 打包成 TS 流并通过 RTP 包传输的方式，关于将 H.264 打包成 RTP 包的方式请参考 `H.264 视频 RTP 负载格式`

## RTP 

## SDP String

```
v=0  
o=- 1453271342214497 1 IN IP4 10.10.42.66  
s=MPEG Transport Stream, streamed by the Vision.lua
i=live.ts  
t=0 0  
a=tool:Vision.lua
a=type:broadcast
a=control:*  
a=range:npt=0-  
a=x-qt-text-nam:MPEG Transport Stream, streamed by the Vision.lua
a=x-qt-text-inf:live.ts  
m=video 0 RTP/AVP 33  
c=IN IP4 0.0.0.0  
b=AS:5000  
a=control:track1  
```


