# TLS

tls (安全传输层)

tls 模块是对安全传输层（TLS）及安全套接层（SSL）协议的实现，按如下方式引用此模块:

```lua
local tls = require('tls');
```

## TLS/SSL 概念

大部分情况下，每个服务器和客户端都应该有一个私钥。

通过 TLS/SSL, 所有的服务器（和一些客户端）必须要一个证书。 证书是相似于私钥的公钥, 它由 CA 或者私钥拥有者数字签名，特别地，私钥拥有者所签名的被称为自签名。 获取证书的第一步是生成一个证书申请文件（CSR)

CSR文件被生成以后，它既能被CA签名也能被用户自签名。

证书被生成以后，它又能用来生成一个 `.pfx` 或者 `.p12` 文件：

## Class: tls.Server

Event: 'newSession'

Event: 'resumeSession'

Event: 'secureConnection'

Event: 'tlsClientError'

server.address()

server.close([callback])

server.listen()

## Class: tls.TLSSocket

### new tls.TLSSocket(socket[, options])

### Event: 'secureConnect'

tlsSocket.address()

tlsSocket.authorized

tlsSocket.encrypted

tlsSocket.getCipher()

tlsSocket.getPeerCertificate([detailed])

tlsSocket.getSession()

tlsSocket.getTLSTicket()

tlsSocket.localAddress

tlsSocket.localPort

tlsSocket.remoteAddress

tlsSocket.remotePort

tls.connect(options[, callback])

tls.createServer([options][, secureConnectionListener])
