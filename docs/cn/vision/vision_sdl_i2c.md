# I2C 接口



I2C 外部总线访问接口

通过 `require('lsdl.i2c')` 调用。

### li2c.new

- deviceName {string} I2C 总线设备名，如 `/dev/i2c-1`
- mode {number} I2C 设备工作模式
- address {number} I2C 设备地址

### i2c:close 

关闭并释放相关的资源

### i2c:crc

- data {string} 要计算 CRC 的数据

返回 8 位 CRC 值

### i2c:read

- length (Number) 要读取的字节数

### i2c:write

- data {string} 要写入的数据，不能超过 2 个字节，超出的部分将不会写入。

### 示例

```lua
local li2c = require('lsdl.i2c')

local I2C_BUS           = '/dev/i2c-1'
local I2C_SLAVE         = 1795
local I2C_ADDRESS       = 0x40 -- SHT21 Address
local i2c = li2c.new(I2C_BUS, I2C_SLAVE, I2C_ADDRESS)

local CMD_SOFT_RESET    = 0xFE
local CMD_TEMPERATURE   = 0xF3
local CMD_HUMIDITY      = 0xF5

i2c:write(string.char(CMD_SOFT_RESET)) -- SOFT RESET
i2c:delay(50, 0)  -- ms

i2c:write(string.char(CMD_TEMPERATURE)) -- READ Temperature
i2c:delay(200, 0) -- ms

local data = i2c:read(3) -- 2 byte value + 1 byte checksum

local crc = i2c:crc(data:sub(1, 2))
assert(crc == data:byte(3))

```