# 加密 (Crypto)

`crypto` 模块提供了加密功能，包括对 mbedtls 的哈希、HMAC、加密、解密、签名、以及验证功能的一整套封装。

使用 `require('crypto')` 来访问该模块。

## Cipher 类

`Cipher` 类的实例用于加密数据。

### checkTag

### finish

### getBlockSize

### getCipherMode

### getIvSize

### getKeyBits

### getName

### getOperation

### getType

### init

### reset

### setIv

### setKey

### setPaddingMode

### update

### updateAd

### writeTag

## Hash 类

`Hash` 类是一个实用工具，用于创建数据的哈希摘要。

[`crypto.createHash()`](http://nodejs.cn/s/ck5B2j) 方法用于创建 `Hash` 实例。

### hash:update

> hash:update(data)

- data `{string}`
- 返回 `{boolean}`

### hash:finish

> hash:finish()

- 返回 `{string}`

## Hmac 类

`Hmac` 类是一个实用工具，用于创建加密的 HMAC 摘要。 

[`crypto.createHmac()`](http://nodejs.cn/s/Pg8qmn) 方法用于创建 `Hmac` 实例。

### hash:update

> hash:update(data)

- data `{string}`
- 返回 `{boolean}`

### hash:finish

> hash:finish()

- 返回 `{string}`

## KeyObject 类

Node.js uses a `KeyObject` class to represent a symmetric or asymmetric key, and each kind of key exposes different functions. 

### canDo

### decrypt

### encrypt

### genKey

### getBitLength

### getLength

### getName

### getType

### sign

### verify

### writeKeyDer

### writeKeyPem

### writePublicKeyDer

### writePublicKeyPem

## crypto 模块的方法和属性

### crypto.createCipher

> crypto.createCipher(algorithm, key, iv[, options])

使用给定的 `algorithm`、 `key` 和初始化向量（`iv`）创建并返回一个 `Cipher` 对象。

- algorithm `{string}`
- key `{string}`
- iv `{string}`

### crypto.createDecipher

> crypto.createDecipher(algorithm, key[, options])

使用给定的 `algorithm`、 `key` 和初始化向量（`iv`）创建并返回一个 `Decipher` 对象。

- algorithm `{string}`
- key `{string}`

### crypto.createHash

> crypto.createHash(algorithm[, options])

创建并返回一个 `Hash` 对象，该对象可用于生成哈希摘要（使用给定的 `algorithm`）。

- algorithm `{string}`

### crypto.createHmac

> crypto.createHmac(algorithm, key[, options])

创建并返回一个 `Hmac` 对象，该对象使用给定的 `algorithm` 和 `key`。

- algorithm `{string}`
- key `{string}`

### crypto.createPrivateKey

> crypto.createPrivateKey(key)

### crypto.createPublicKey

> crypto.createPublicKey(key)

### crypto.generateKeyPair

> crypto.generateKeyPair(type, options, callback)

Generates a new asymmetric key pair of the given `type`. RSA, DSA, EC, Ed25519 and Ed448 are currently supported.

- type `{string}`
- options `{object}`
- callback `{function}`

### crypto.getCiphers

> crypto.getCiphers()

Returns An array with the names of the supported cipher algorithms.

- 返回 `string[]`

### crypto.getHashes

> crypto.getHashes()

Returns An array of the names of the supported hash algorithms, such as `'RSA-SHA256'`. Hash algorithms are also called "digest" algorithms.

- 返回 `string[]`

### crypto.privateDecrypt

> crypto.privateDecrypt(privateKey, buffer)

Decrypts `buffer` with `privateKey`. `buffer` was previously encrypted using the corresponding public key, for example using [`crypto.publicEncrypt()`](http://nodejs.cn/s/29Bw9o).

- privateKey `{string|object}`
- buffer `{string}`
- 返回:  `string`

### crypto.privateEncrypt

> crypto.privateEncrypt(privateKey, buffer)

Encrypts `buffer` with `privateKey`. The returned data can be decrypted using the corresponding public key, for example using [`crypto.publicDecrypt()`](http://nodejs.cn/s/r7kK6n).

- privateKey `{string|object}`
- buffer `{string}`
- 返回:  `string`

### crypto.publicDecrypt

> crypto.publicDecrypt(key, buffer)

Decrypts `buffer` with `key`.`buffer` was previously encrypted using the corresponding private key, for example using [`crypto.privateEncrypt()`](http://nodejs.cn/s/xHazLP).

- key `{string|object}`
- buffer `{string}`
- 返回:  `string`

### crypto.publicEncrypt

> crypto.publicEncrypt(key, buffer)

Encrypts the content of `buffer` with `key` and returns a new [`Buffer`](http://nodejs.cn/s/FP4oTy) with encrypted content. The returned data can be decrypted using the corresponding private key, for example using [`crypto.privateDecrypt()`](http://nodejs.cn/s/RU1YFJ).

- key `{string|object}`
- buffer `{string}`
- 返回:  `string`

### crypto.randomBytes

> crypto.randomBytes(size[, callback])

生成加密强伪随机数据。 `size` 参数是指示要生成的字节数的数值。

- size `{number}`
- 返回:  `string` 如果未提供 `callback` 函数。

### crypto.sign

> crypto.sign(algorithm, data, key)

Calculates and returns the signature for `data` using the given private key and algorithm. 

- algorithm `{string}`
- data `{string}`
- key `{string|object}`
- 返回:  `string`

### crypto.verify

> crypto.verify(algorithm, data, key, signature)

Verifies the given signature for `data` using the given key and algorithm.

- algorithm `{string}`
- data `{string}`
- key `{string|object}`
- signature `{string}`
- 返回:  `boolean`

