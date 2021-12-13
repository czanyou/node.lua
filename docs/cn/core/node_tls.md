# 安全传输层 (TLS)

tls 模块是对安全传输层（TLS）及安全套接层（SSL）协议的实现，按如下方式引用此模块:

```lua
local tls = require('tls');
```

## TLS/SSL 概念

TLS/SSL 是公共/私人的密钥基础设施（PKI）。 大部分情况下，每个服务器和客户端都应该有一个私钥。

私钥能有多种生成方式，下面举一个例子。 用 OpenSSL 的命令行来生成一个 2048 位的 RSA 私钥：

```sh
openssl genrsa -out ryans-key.pem 2048
```

通过 TLS/SSL，所有的服务器（和一些客户端）必须要一个证书。 证书是相似于私钥的公钥, 它由 CA 或者私钥拥有者数字签名，特别地，私钥拥有者所签名的被称为自签名。 获取证书的第一步是生成一个证书申请文件 (CSR)。

用 OpenSSL 能生成一个私钥的 CSR 文件：

```sh
openssl req -new -sha256 -key ryans-key.pem -out ryans-csr.pem
```

CSR 文件被生成以后，它既能被 CA 签名也能被用户自签名。 用 OpenSSL 生成一个自签名证书的命令如下：

```sh
openssl x509 -req -in ryans-csr.pem -signkey ryans-key.pem -out ryans-cert.pem
```

证书被生成以后，它又能用来生成一个 `.pfx` 或者 `.p12` 文件：

```sh
openssl pkcs12 -export -in ryans-cert.pem -inkey ryans-key.pem -certfile ca-cert.pem -out ryans.pfx
```

命令行参数:

- `in`: 被签名的证书。
- `inkey`: 有关的私钥。
- `certfile`: 签入文件的证书串，比如： `cat ca1-cert.pem ca2-cert.pem > ca-cert.pem`。

## 类: tls.Server

继承自 `net.Server`

### 事件

#### Event: 'newSession'

#### Event: 'resumeSession'

#### Event: 'secureConnection'

#### Event: 'tlsClientError'

### server.address

> server.address()



### server.close

> server.close([callback])



### server.listen

>  server.listen()

## 类: TLSSocket

继承自 `net.Socket`

### new 

>  new tls.TLSSocket(socket[, options])

### 事件

#### Event: 'secureConnect'

### 属性

#### tlsSocket.authorized

#### tlsSocket.encrypted

#### tlsSocket.localAddress

#### tlsSocket.localPort

#### tlsSocket.remoteAddress

#### tlsSocket.remotePort

### tlsSocket.getPeerCertificate

>  tlsSocket.getPeerCertificate([detailed])

## tls.connect

>  tls.connect(options[, callback])

- options {object}
- callback {function}

## tls.createServer

>  tls.createServer(options, [secureConnectionListener])

- options {object}
- secureConnectionListener {function}