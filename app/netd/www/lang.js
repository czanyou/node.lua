var VisionLangZh =
{
	Device				: "设备",
	DeviceInfo			: "设备信息",
	DeviceName			: "设备名称",
	DeviceCPU			: "处理器",
	DeviceMemmory		: "内存",
	DeviceStorage		: "存储",
	DeviceStatus		: "设备状态",
	WANStatus			: "Internet 状态",
	Wireless			: "无线",
	WirelessEnable		: "开启 WiFi 无线网络",
	WirelessNote		: "<b>注意:</b> 在配置完成后, 你必须拔出电源线和网线, 然后再插上电源线, 才会切换到无线网络.",
	WirelessNotFound	: "注意: 没有找到任何可用的无线网络设备, 您的设备可能没有安装无线网卡或者没有正确连接, 暂时无法使用无线网络.",
	WirelessSettings	: "WiFi 设置",
	WLAN				: "无线网络",
	WlChannel			: "无线频道",
	WlEncryption		: "无线加密",
	WlSelect			: "选取附近的 WiFi ...",
	WlScan				: "扫描",
	WlESSID				: "SSID",
	WlKey				: "密码",
	WlManaged			: "Managed (默认)",
	WlMode				: "无线网络模式",
	WlNetwork			: "可用无线网络",
	WlQuality			: "信号强度",
	
	NetDhcpMode			: "通过 DHCP 获取",
	NetDNSServer		: "DNS 地址",
	NetDNSServer1		: "首选 DNS 服务器",
	NetDNSServer2		: "备选 DNS 服务器",
	NetGateway			: "网关",
	NetIPAddress		: "IP 地址",
	NetIPChangeTip		: "系统发现配置的 IP 地址和当前访问的地址不同, 如果您刚刚修改了设备的 IP 地址, 您可以点击下面的链接来访问新的地址",
	NetIPErrorAddress	: "无效的 IP 地址.",
	NetIPMode			: "配置 IP 地址",
	NetMACAddress		: "MAC 地址",
	NetRouter			: "路由器",
	NetStaticMode		: "静态 IP 地址",
	NetSubnetMask		: "子网掩码",
	Network				: "网络",
	NetworkConfirm		: "修改网络参数后会重新配置网络, 设备可能会分配新的不同的 IP 地址或者因不当的设置导致网络断开, 你确认要修改并继续提交吗?",
	NetworkSettings		: "网络设置",
	NetworkStatus		: "网络状态",

	IPSettings			: "IP 设置",
	Ethernet			: "有线",
	


	EndItem 			: ""
}

var VisionLangEn =
{
	UserCurrentPassword : "Current Password",
	DeviceMemmory		: "Memmory",
	DeviceCPU			: "Process",
	DeviceStorage		: "Storage",
	DeviceRoot			: "Root Path",
	DeviceURL			: "URL",
	NetDhcpMode			: "Assign by DHCP",
	NetDNSServer		: "DNS Server",
	NetDNSServer1		: "Primary DNS",
	NetDNSServer2		: "Secondary DNS",
	NetGateway			: "Default Gateway",
	NetIPAddress		: "IP Address",
	NetIPChangeTip		: "If you had changed the IP address, you can click this link to access the new address",
	NetIPErrorAddress	: "Invalid IP Address",
	NetIPMode			: "Configure IP",
	NetMACAddress		: "MAC Address",
	NetRouter			: "Router Address",
	NetStaticMode		: "Static IP Address",
	NetSubnetMask		: "Subnet Mask",
	Network				: "Network",
	NetworkConfirm		: "Are you sure want to contiune?",
	NetworkSettings		: "Network Settings",
	NetworkStatus		: "Network Status",

	UpgradeOnline		: "Upgrade Online",
	UpgradeLocal		: "Upgrade Local",
	FirmwareLatest		: "Latest Version",
	UpgradeFile			: "Upgrade File",
	UpgradeCheck		: "Check",

	WANStatus			: "Wide Area Network Status",
	Wireless			: "Wireless",
	WirelessEnable		: "Enable Wi-Fi Network",
	WirelessNote		: "<b>Note:</b> After wireless configurations are completed, you have to unplug the power and Ethernet cable from the device; then re-plug the power cable. The device will switch to wireless mode.",
	WirelessNotFound	: "Not found any wireless network device.",
	WirelessSettings	: "Wi-Fi Settings",
	WLAN				: "Wi-Fi",
	WlChannel			: "Channel",
	WlEncryption		: "Encryption",
	WlSelect			: "Select a Wi-Fi Access Point ...",
	WlScan				: "Scan",
	WlESSID				: "Network SSID",
	WlKey				: "Password",
	WlManaged			: "Managed (Default)",
	WlMode				: "Wireless Mode",
	WlNetwork			: "Wi-Fi Networks",
	WlQuality			: "Quality",
	WlStatus			: "Wireless Network Status",
	

	EndItem 			: ""

}


$.lang.update('zh-cn', VisionLangZh)
$.lang.update('en', VisionLangEn)
