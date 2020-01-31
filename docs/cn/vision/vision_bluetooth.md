# Bluetooth 低功耗蓝牙

扫描或接收低功耗蓝牙设备广播

通过 `require('device/bluetooth')` 调用。

## bluetooth.startScan

    bluetooth.startScan(options, callback)
    bluetooth.startScan(callback)

开始扫描

- options {object} 扫描选项
- callback {function} - function(err, data)
    当接收到任何 BLE 广播数据时调用这个函数

## bluetooth.stopScan

    bluetooth.stopScan()

停止扫描

