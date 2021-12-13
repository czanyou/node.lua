const $wot = {

    /**
     * 解析指定的 URL 的 Query 部分
     * @param {string} urlString 要解析的 URL 字符串, 未指定则默认为 location.search
     * @returns {object}
     */
    parseQueryString: function (urlString) {
        urlString = urlString || location.search;
        if ((typeof urlString) !== 'string') {
            return {}
        }

        const search = urlString.split('?')[1]
        if (!search) {
            return {};
        }

        const result = {}
        const tokens = search.split('&');
        for (let i = 0; i < tokens.length; i++) {
            const items = tokens[i].split('=');
            const name = items[0];
            const value = items[1];
            result[name] = decodeURIComponent(value);
        }

        return result;
    },

    param: function (params) {
        let result = '';
        for (let key in params) {
            const value = params[key]
            if (result) {
                result += '&'
            }
            result += key;
            result += '='
            result += encodeURIComponent(value);
        }

        return result;
    },

    isIpAddress: function (address) {
        if (!address) {
            return false;
        }

        const pattern = /^((25[0-5]|2[0-4]\d|((1\d{2})|([1-9]?\d)))\.){3}(25[0-5]|2[0-4]\d|((1\d{2})|([1-9]?\d)))$/;
        return pattern.test(address)
    },

    isIpAddressList: function (value) {
        if (!value) {
            return false;
        }
        const tokens = value.split(' ')
        for (let i = 0; i < tokens.length; i++) {
            if (!$wot.isIpAddress(tokens[i])) return false;
        }

        return true;
    },
    post: function (url, data, onsuccess, onerror) {
        if (typeof data == 'object') {
            data = JSON.stringify(data);
        }

        return ajax({
            url: url,
            data: data,
            type: 'post',
            cache: false,
            processData: false,
            contentType: 'application/json',
            success: onsuccess,
            error: onerror
        })
    },
    getErrorMessage: function (error) {
        if (!error) {
            return 'Unknown error'
        }

        const type = typeof error
        if (type == 'object') {
            return error.message || error.error || error.code || JSON.stringify(error)
        }

        return error
    },
    isEmpty: function (data) {
        if (!data) {
            return true;

        } else if (Array.isArray(data)) {
            if (data.length <= 0) {
                return true;
            }

        } else if (typeof data == 'object') {
            let count = 0;
            for (let key in data) {
                return false;
            }

            return true;
        }

        return false;
    }
}

$wot.langs = {};

const BaseSettingBlock = {
    data: function () {
        return {
            active: false,
            lang: {},
            responseData: null,
            updateStatus: null
        }
    },
    props: ['active'],
    mounted: function () {
        const defaultLang = $wot.langs['en-US'] || {};
        this.lang = Object.assign({}, defaultLang, $wot.langs['zh-CN']);

        const self = this;
        this.$nextTick(function () {
            if (self.active && self.onRefreshClick) {
                self.onRefreshClick();
            }
        })
    },
    methods: {
        getRegisterState: function (register) {
            const registerStates = ['Unregister', 'Registered']
            const state = (register && register.state) || 0;
            return registerStates[state] || state || '-'
        },
        getExpiresTime: function (register) {
            let expires = (register && register.expires) || 3600
            const updated = (register && register.updated) || 0
            if (updated <= 0) {
                return updated
            }

            expires = updated + expires * 1000;
            return this.getTimeSpanString(expires)
        },
        getTimeSpan: function (time) {
            return this.getTimeSpanString(Date.now(), time) + ' ' + this.lang.tip_ago;
        },
        getTimeSpanString: function (time1, time2) {
            time2 = time2 || Date.now();
            if (!time1) {
                return
            }

            let span = Math.floor((time1 - time2) / 1000);
            let absSpan = Math.abs(span)
            if (absSpan <= 60) {
                return span + 's'

            } else if (absSpan <= 3600) {
                span = Math.floor(span / 60);
                return span + 'm'

            } else if (absSpan <= 3600 * 24) {
                span = Math.floor(span / 3600);
                return span + 'h'

            } else if (absSpan <= 3600 * 24) {
                span = Math.floor(span / (3600 * 24));
                return span + 'd'
            }
        },
        isEmpty: function (data) {
            return $wot.isEmpty(data)
        },
        onConfigLoad: function (url, callback) {
            const self = this
            ajax.get(url, function (result) {
                if (!result || result.error) {
                    self.updateStatus = 'Load failed, ' + $wot.getErrorMessage(result);
                    self.showErrorResult(result);
                    return;
                }

                self.updateStatus = null;
                if (callback) {
                    callback(result);
                }
            });
        },
        onConfigSave: function (path, data, callback) {
            try {
                const self = this;
                if (self.saveStatusTimer) {
                    clearTimeout(self.saveStatusTimer)
                    self.saveStatusTimer = null;
                }

                self.updateStatus = self.lang.tip_saving;

                $wot.post(path, data, function (result) {
                    if (!self.saveStatusTimer) {
                        self.saveStatusTimer = setTimeout(function () {
                            self.updateStatus = null;
                            self.saveStatusTimer = null;
                        }, 5000);
                    }

                    self.updateStatus = '<span class="text-success">' + self.lang.tip_save_successfully + '</span>'
                    if (callback) {
                        callback(result);
                    }

                }, function (result) {
                    self.updateStatus = self.lang.tip_save_failed + ', ' + $wot.getErrorMessage(result);
                })

            } catch (error) {
                self.updateStatus = self.lang.tip_save_failed + ', ' + $wot.getErrorMessage(error);
            }
        },
        onGatewayConfigReload: function () {
            const self = this
            if (!window.confirm("Are you sure want to reload and apply the config?")) {
                return;
            }

            const url = "/system/action";
            const data = { reload: 2 }

            ajax.post(url, data, function (result) {
                self.showResultMessage(result)
            });

            return false;
        },
        showResultMessage: function (result, message) {
            message = message || ''

            const self = this
            if (result && result.output) {
                message += result.output;
            } else {
                message += JSON.stringify(result, null, '  ');
            }

            self.responseData = message
        },
        showErrorResult: function (result, message) {
            const code = result && result.code
            if (code == 401) {
                location.reload();
            }
        }
    }
}

const OverviewBlockComponent = {
    extends: BaseSettingBlock,
    template: '#overview-block-template',
    data: function () {
        return {
            device: null, // 设备信息
            lanStatus: null, // 以太网信息
            registerStatus: null, // 注册消息
            status: null, // 设备状态信息
            systemStatus: null, // 系统状态信息
            wanStatus: null // 公网信息
        }
    },
    mounted: function () {},
    methods: {
        onSystemStatusChange: function (result) {
            this.status = result.system || {}
            this.device = result.device || {}
            this.firmware = result.firmware || {}
            this.ifaces = result.network || []
        },
        loadRegisterStatus: function () {
            const self = this
            const url = "/status/wotc/status";
            this.onConfigLoad(url, function (result) {
                self.registerStatus = result
            });
        },
        loadSystemStatus: function () {
            const self = this
            const url = "/system/status";
            console.log('loadSystemStatus', url);
            this.onConfigLoad(url, function (result) {
                self.systemStatus = result;

                console.log('loadSystemStatus', result);
                const network = result.network;
                self.wanStatus = network && network.wan;
                self.lanStatus = network && network.lan;
                self.status = result.system || {}
            });

            return false;
        },
        onRefreshClick: function () {
            this.registerStatus = null;
            this.systemStatus = null;

            this.loadRegisterStatus();
            this.loadSystemStatus();
        }
    }
}

Vue.component('overview-block', OverviewBlockComponent);

const NetworkBlockComponent = {
    extends: BaseSettingBlock,
    template: '#network-block-template',
    props: ['config'],
    data: function () {
        return {
            network: {}
        }
    },
    mounted: function () { },
    methods: {
        loadNetworkConfig: function () {
            const defaultSettings = {
                ip: '192.168.8.12',
                netmask: '255.255.255.0',
                router: '192.168.8.1',
                dns1: '223.5.5.5',
                dns2: '8.8.8.8',
                proto: 'static',
                wan_proto: 'none'
            }

            const self = this
            const url = "/config/network";
            this.onConfigLoad(url, function(result) {
                self.network = Object.assign({}, defaultSettings, result);

                const dns = self.network.dns;
                if (dns) {
                    const tokens = dns.split(' ');
                    self.network.dns1 = tokens[0];
                    self.network.dns2 = tokens[1];
                }
            });

            return false;
        },
        onNetworkFormValidity: function () {
            const self = this;
            function onFormItemValidity(element) {
                const value = element.value;
                let message = '';
                if (element.required) {
                    if (value == null || value == '') {
                        message = self.lang.validity_missing;
                    }
                }

                const format = element.dataset.format;
                if (format) {
                    if (format == 'ip' && !$wot.isIpAddress(value)) {
                        message = self.lang.validity_invalid_ip;
                    }
                }

                if (message) {
                    element.focus();
                    throw { message: message };
                }
            }

            try {
                const form = this.$refs.networkForm;
                onFormItemValidity(form.ip);
                onFormItemValidity(form.netmask);
                onFormItemValidity(form.router);
                onFormItemValidity(form.dns1);
                onFormItemValidity(form.dns2);

            } catch (message) {
                self.updateStatus = $wot.getErrorMessage(message);
                return false;
            }

            return true;
        },
        onNetworkConfigSubmit: function () {
            const self = this

            const data = Object.assign({}, this.network);
            if (data.proto == "static") {
                if (!this.onNetworkFormValidity()) {
                    return;
                }
            }

            data.dns = data.dns1 || '';
            if (data.dns2) {
                data.dns = data.dns + ' ' + data.dns2
            }

            const url = "/config/network";
            this.onConfigSave(url, data, function (result) { });
            return false;
        },
        onRefreshClick: function () {
            this.updateStatus = null;
            this.loadNetworkConfig();
        }
    }
}

Vue.component('network-block', NetworkBlockComponent);

const RegisterBlockComponent = {
    extends: BaseSettingBlock,
    template: '#register-block-template',
    props: ['config'],
    data: function () {
        return {
            register: {},
            registerStatus: null
        }
    },
    mounted: function () { },
    methods: {
        loadRegisterConfig: function () {
            const self = this
            const url = "/config/register";
            this.onConfigLoad(url, function (result) {
                self.register = result
            });

            return false;
        },
        loadRegisterStatus: function () {
            const self = this
            const url = "/status/wotc/status";
            this.onConfigLoad(url, function (result) {
                self.registerStatus = result;
            });
        },
        onRefreshClick: function () {
            this.updateStatus = this.lang.tip_loading;
            this.register = {};
            this.registerStatus = null;
            this.loadRegisterConfig();
            this.loadRegisterStatus();
        },
        onRegisterConfigSubmit: function () {
            const self = this
            const url = "/config/register";
            const data = Object.assign({}, this.register);
            this.onConfigSave(url, data, function (result) { });
            return false;
        }
    }
}

Vue.component('register-block', RegisterBlockComponent);

const FirmwareBlockComponent = {
    extends: BaseSettingBlock,
    template: '#firmware-block-template',
    props: ['config'],
    data: function () {
        return {
            current: {},
            firmware: {},
            firmwareStatus: null,
            firmwareUploadStatus: null,
            status: {},
            upload: {}
        }
    },
    mounted: function () { },
    watch: {
        active: function (active) {
            if (active) {
                this.loadFirmwareStatus()
            }
        }
    },
    methods: {
        getUpdateState: function(state) {
            if (!state) {
                return '-';
            }

            const lang = this.lang;
            return lang['firmware_state_' + state] || state
        },
        getUpdateResult: function (result) {
            if (!result) {
                return '-';
            }

            const lang = this.lang;
            return lang['firmware_result_' + result] || result
        },
        getUpdateTime: function (updated) {
            if (updated) {
                return this.getTimeSpanString(Date.now(), updated) + ' ' + this.lang.tip_ago;
            }
            return updated;
        },
        onFirmwareInstall: function () {
            const self = this;
            if (self.firmwareUploadStatus) {
                return;
            }

            const message = this.lang.firmware_install_confirm;
            this.firmwareUploadStatus = this.lang.firmware_installing;
            this.onSystemAction(message, null, { install: 3 }, function() {
                self.firmwareUploadStatus = null;
            });

            this.onRefreshClick();
            return false;
        },
        onFirmwareUpload: function () {
            const self = this;
            if (self.firmwareUploadStatus) {
                return;
            }

            self.firmwareUploadStatus = this.lang.firmware_uploading;
            self.responseData = null

            const form = document.getElementById('firmware-form')
            const formData = new FormData(form);
            ajax({
                url: '/upload',
                data: formData,
                type: 'post',
                cache: false,
                processData: false,
                contentType: 'multipart/form-data',
                success: function (result) {
                    self.firmwareUploadStatus = null;
                    self.showResultMessage(result)
                },
                error: function (result) {
                    self.firmwareUploadStatus = null;
                    self.showResultMessage(result)
                }
            })
        },
        onSystemAction: function (message, title, data, callback) {
            const self = this
            if (message && !window.confirm(message)) {
                return;
            }

            const url = "/system/action";
            this.responseData = null

            this.updateStatus = title;
            ajax.post(url, data, function (result) {
                self.updateStatus = null;
                self.showResultMessage(result)

                if (callback) {
                    callback(result)
                }
            });

            return false;
        },
        onSystemReboot: function () {
            const message = this.lang.device_reboot_confirm;
            this.onSystemAction(message, null, { reboot: 5 });
            return false;
        },
        onSystemReset: function () {
            const message = this.lang.device_reset_confirm;
            this.onSystemAction(message, null, { reset: 3 }, function() {
                if (!(!result || result.error)) {
                    setTimeout(function () {
                        location.href = '/?v=' + Date.now()
                    }, 5000)
                }
            });
            return false;
        },
        onSystemUpdate: function () {
            const status = this.lang.firmware_updating;
            this.onSystemAction(null, status, { update: 1 });
            this.onRefreshClick();
            return false;
        },
        onSystemUpgrade: function () {
            const message = this.lang.firmware_upgrade_confirm;
            const status = this.lang.firmware_upgrading;
            this.onSystemAction(message, status, { upgrade: "system" });
            this.onRefreshClick();
            return false;
        },
        onRefreshClick: function () {
            if (this.timeoutTimer) {
                clearTimeout(this.timeoutTimer)
                this.timeoutTimer = null;
            }

            this.timeoutTimer = setTimeout(function () {
                this.timeoutTimer = null;

                if (this.refreshTimer) {
                    clearTimeout(this.refreshTimer)
                    this.refreshTimer = null;
                }

            }, 20 * 1000);

            if (this.refreshTimer) {
                return;
            }

            const self = this;
            this.refreshTimer = setInterval(function () {
                self.loadFirmwareStatus()
            }, 1000);
        },
        loadFirmwareStatus: function () {
            const self = this

            if (!this.active) {
                return;
            }

            const url = "/firmware/status";
            this.onConfigLoad(url, function (result) {
                self.firmwareStatus = result;

                self.current = result.current || {};
                self.firmware = result.firmware || {};
                self.status = result.status || {};
                self.upload = result.upload || {};
            });

            return false;
        }
    }
}

Vue.component('firmware-block', FirmwareBlockComponent);

const GatewayBlockComponent = {
    extends: BaseSettingBlock,
    template: '#gateway-block-template',
    data: function () {
        return {
            config: null,
            configString: null,
            currentEntity: null,
            peripherals: null,
            showSidebar: false,
            showSourceCode: false
        }
    },
    watch: {
        configString: function (configString) {
            this.onConfigUpdate();
        }
    },
    methods: {
        getPeripherals: function (gatewayConfig) {
            gatewayConfig = gatewayConfig || {};
            const peripherals = [];
            for (let type in gatewayConfig) {
                const list = gatewayConfig[type];
                if (!Array.isArray(list)) {
                    continue;
                }

                for (let i = 0; i < list.length; i++) {
                    const item = list[i];
                    const peripheral = Object.assign({}, item)
                    peripheral.type = type;
                    peripheral.index = peripherals.length;
                    peripherals.push(peripheral)
                }
            }

            return peripherals;
        },
        loadGatewayConfig: function () {
            const self = this
            const url = "/config/gateway";
            ajax.get(url, function (result) {
                self.config = result || {}
                self.onConfigChange(self.config);
            });

            return false;
        },
        onConfigChange: function (config) {
            if (!config || config.code == -404) {
                this.configString = "{\r\n}";
                return;
            }

            // console.log('gatewayConfig', config)
            this.configString = config && JSON.stringify(config, null, '\t')
        },
        onConfigReload: function () {
            this.onGatewayConfigReload()
        },
        onConfigUpdate: function () {
            try {
                const gatewayConfig = JSON.parse(this.configString);
                this.peripherals = this.getPeripherals(gatewayConfig);
                this.updateStatus = null;
            } catch (e) {
            }
        },
        onConfigSubmit: function () {
            const self = this

            // 验证 JSON format
            const gatewayConfig = JSON.parse(self.configString);
            delete gatewayConfig.code;
            gatewayConfig.updated = Date.now();
            const data = JSON.stringify(gatewayConfig);

            const url = '/config/gateway';
            this.onConfigSave(url, data, function (result) {
                self.onRefreshClick();
            });
        },
        onEntityClick: function(entity) {
            this.currentEntity = entity;
            this.showSidebar = true;
        },
        onRefreshClick: function () {
            this.updateStatus = null;
            this.currentEntity = null;
            this.config = null;
            this.configString = null;
            this.peripherals = null;
            this.showSidebar = false;
            this.loadGatewayConfig();
        }
    }
}

Vue.component('gateway-block', GatewayBlockComponent);

const PeripheralBlockComponent = {
    extends: BaseSettingBlock,
    template: '#peripherals-block-template',
    props: ['config'],
    data: function () {
        return {
            peripheralsConfig: null
        }
    },
    mounted: function () { },
    methods: {
        loadPeripheralsConfig: function () {
            const self = this
            const url = "/config/peripherals";
            this.onConfigLoad(url, function (result) {
                if (!result || result.code == -404) {
                    self.peripheralsConfig = "{\r\n}";
                    return;
                }

                self.peripheralsConfig = JSON.stringify(result, null, '\t')
            });

            return false;
        },
        onConfigReload: function () {
            this.onGatewayConfigReload()
        },
        onConfigSubmit: function () {
            const self = this
            // 验证 JSON format
            const peripheralsConfig = JSON.parse(self.peripheralsConfig) || {}
            delete peripheralsConfig.code;
            peripheralsConfig.updated = Date.now();
            const data = JSON.stringify(peripheralsConfig);

            const url = '/config/peripherals';
            this.onConfigSave(url, data, function (result) {
                self.loadPeripheralsConfig()
            });
        },
        onRefreshClick: function () {
            this.updateStatus = null;
            this.loadPeripheralsConfig()
        }
    }
}

Vue.component('peripherals-block', PeripheralBlockComponent);

const ScriptBlockComponent = {
    extends: BaseSettingBlock,
    template: '#script-block-template',
    props: ['config'],
    data: function () {
        return {
            scriptConfig: null
        }
    },
    mounted: function () { },
    methods: {
        loadScriptConfig: function () {
            const self = this
            const url = "/config/script";
            this.onConfigLoad(url, function (result) {
                const script = result && result.data;

                if (!result || result.code == -404) {
                    self.scriptConfig = "\r\n";
                    return;
                }
                
                self.scriptConfig = script
            });

            return false;
        },
        onConfigSubmit: function () {
            const self = this
            // 验证 JSON format
            const script = self.scriptConfig || ''
            const scriptConfig = {}
            scriptConfig.data = script;
            scriptConfig.updated = Date.now();
            const data = JSON.stringify(scriptConfig);

            const url = '/config/script';
            this.onConfigSave(url, data, function (result) {
                self.loadScriptConfig()
            });
        },
        onRefreshClick: function () {
            this.loadScriptConfig();
        }
    }
}

Vue.component('script-block', ScriptBlockComponent);

const UartBlockComponent = {
    extends: BaseSettingBlock,
    template: '#uart-block-template',
    data: function () {
        return {
            config: null,
            uart1: {},
            uart2: {}
        }
    },
    methods: {
        loadGatewayConfig: function () {
            const self = this
            const url = "/config/gateway";
            ajax.get(url, function (result) {
                self.config = result || {}
                self.onConfigChange(self.config);
            });

            return false;
        },
        onConfigChange: function (gatewayConfig) {
            const defaultSettings = {
                baudrate: 9600,
                databits: 8,
                device: 2,
                parity: 78,
                stopbits: 1
            }

            const uarts = gatewayConfig && gatewayConfig.uarts
            this.uart1 = Object.assign({}, defaultSettings, (uarts && uarts[1]));
            this.uart2 = Object.assign({}, defaultSettings, (uarts && uarts[2]));
        },
        onConfigSubmit: function () {
            function getUartSettings(config, device) {
                const uart = { device: device }
                let flags = 0;

                if (config.baudrate) {
                    uart.baudrate = Number.parseInt(config.baudrate)
                    flags++;
                }

                if (config.parity) {
                    uart.parity = Number.parseInt(config.parity)
                    flags++;
                }

                if (config.databits) {
                    uart.databits = Number.parseInt(config.databits)
                    flags++;
                }

                if (config.stopbits) {
                    uart.stopbits = Number.parseInt(config.stopbits)
                    flags++;
                }

                return flags ? uart : null;
            }

            const self = this

            let uarts = {};
            uarts[1] = getUartSettings(self.uart1, 1);
            uarts[2] = getUartSettings(self.uart2, 2);

            const flags = uarts[1] && uarts[2];
            if (!flags) {
                uarts = null;
            }

            self.onGatewayConfigSave('uarts', uarts);
        },
        onGatewayConfigSave: function (name, value) {
            const self = this

            // 验证 JSON format
            const gatewayConfig = this.config || {}
            if (value != null) {
                gatewayConfig[name] = value;
            } else {
                delete gatewayConfig[name];
            }

            delete gatewayConfig.code;
            gatewayConfig.updated = Date.now();
            const data = JSON.stringify(gatewayConfig);

            const url = '/config/gateway';
            this.onConfigSave(url, data, function (result) {
                self.onRefreshClick();
            });
        },
        onRefreshClick: function () {
            this.updateStatus = null;
            this.loadGatewayConfig();
        }
    }
}

Vue.component('uart-block', UartBlockComponent);

const LoraBlockComponent = {
    extends: BaseSettingBlock,
    template: '#lora-block-template',
    props: ['config'],
    data: function () {
        return {
            lora: {}
        }
    },
    mounted: function () { },
    methods: {
        loadLoraConfig: function () {
            const defaultSettings = {
                enable: 1,
                address: 22,
                rate: 0,
                parity: 78,
                frequency: 4700,
                network: 22,
                tpl: 1
            };

            const self = this
            const url = "/config/lora";
            this.onConfigLoad(url, function (result) {
                self.lora = Object.assign({}, defaultSettings, result);
            });

            return false;
        },
        onLoRAConfigSubmit: function () {
            function getLoRASettings(config, device) {
                const lora = { device: device }
                let flags = 0;

                if (config.enable || config.enable == 0) {
                    lora.enable = Number.parseInt(config.enable)
                    flags++;
                }

                if (config.address || config.address == 0) {
                    lora.address = Number.parseInt(config.address)
                    flags++;
                }

                if (config.rate || config.rate == 0) {
                    lora.rate = Number.parseInt(config.rate)
                    flags++;
                }

                if (config.tpl || config.tpl == 0) {
                    lora.tpl = Number.parseInt(config.tpl)
                    flags++;
                }

                if (config.frequency || config.frequency == 0) {
                    lora.frequency = Number.parseInt(config.frequency)
                    flags++;
                }

                if (config.network || config.network == 0) {
                    lora.network = Number.parseInt(config.network)
                    flags++;
                }

                return flags ? lora : null;
            }

            const lora = getLoRASettings(this.lora, 2);
            this.onLoraConfigSave(lora);
        },
        onLoraConfigSave: function (lora) {
            lora = lora || {}
            const self = this
            lora.updated = Date.now();
            const data = JSON.stringify(lora);

            const url = '/config/lora';
            this.onConfigSave(url, data, function (result) {

            });
        },
        onRefreshClick: function () {
            this.updateStatus = null;
            this.loadLoraConfig();
        }
    }
}

Vue.component('lora-block', LoraBlockComponent);

const ModbusBlockComponent = {
    extends: BaseSettingBlock,
    template: '#modbus-block-template',
    data: function () {
        return {
            modbus: null
        }
    },
    methods: {
        getActions: function (device) {
            const actions = device && device.modbus && device.modbus.actions;
            if (!actions) {
                return [];
            }

            const stat = device.stat

            const result = [];
            for (const name in actions) {
                const action = actions[name];
                const statInfo = stat && stat[name];

                result.push(Object.assign({ name: name }, action, statInfo));
            }

            result.sort(function (a, b) { return (a.register > b.register) ? 1 : -1 })
            return result;
        },
        getProperties: function (device) {
            const properties = device && device.modbus && device.modbus.properties;
            if (!properties) {
                return [];
            }

            const stat = device.stat

            const result = [];
            for (const name in properties) {
                const property = properties[name];
                const statInfo = stat && stat[name];

                result.push(Object.assign({ name: name }, property, statInfo));
            }

            result.sort(function (a, b) { return (a.register > b.register) ? 1 : -1 })
            return result;
        },
        isEmpty: function (data) {
            if (!data) {
                return;
            }

            const values = Object.values(data);
            return !values || values.length <= 0;
        },
        loadModbusStatus: function () {
            const self = this
            const url = "/status/gateway/modbus";
            ajax.get(url, function (result) {
                self.modbus = result;
            });
        },
        onRefreshClick: function () {
            this.loadModbusStatus();
        },
        toArray: function (map) {
            const result = [];

            for (const name in map) {
                result.push(Object.assign({ name: name }, map[name]))
            }

            result.sort(function (a, b) { return (a.register > b.register) ? 1 : -1 })
            return result;
        }
    }
}

Vue.component('modbus-block', ModbusBlockComponent);

const BluetoothBlockComponent = {
    extends: BaseSettingBlock,
    template: '#bluetooth-block-template',
    data: function () {
        return {
            beacons: null
        }
    },
    mounted: function () { },
    methods: {
        loadBluetoothStatus: function () {
            const self = this
            const url = "/status/gateway/beacons";
            this.onConfigLoad(url, function (result) {
                self.beacons = result;
            });
        },
        onRefreshClick: function () {
            this.loadBluetoothStatus();
        }
    }
}

Vue.component('bluetooth-block', BluetoothBlockComponent);

const MediaBlockComponent = {
    extends: BaseSettingBlock,
    template: '#media-block-template',
    data: function () {
        return {
            currentDevice: null,
            media: null
        }
    },
    mounted: function () { },
    methods: {
        loadMediaStatus: function () {
            const self = this
            const url = "/status/gateway/media";
            this.onConfigLoad(url, function (result) {
                for (const key in result) {
                    const device = result[key];
                    if (!device) {
                        continue;
                    }

                    const deviceInformation = device.deviceInformation
                    if (deviceInformation) {
                        device.model = deviceInformation.Model
                        device.serialNumber = deviceInformation.SerialNumber
                        device.version = deviceInformation.FirmwareVersion
                        device.manufacturer = deviceInformation.Manufacturer
                    }
                }

                self.media = result;
            });
        },
        onDeviceClick: function (did) {
            const media = this.media;
            this.currentDevice = media && media[did];
        },
        onRefreshClick: function () {
            this.currentDevice = null;
            this.loadMediaStatus();
        }
    }
}

Vue.component('media-block', MediaBlockComponent);

const ThingsBlockComponent = {
    extends: BaseSettingBlock,
    template: '#things-block-template',
    data: function () {
        return {
            config: null,
            peripherals: null,
            things: null
        }
    },
    mounted: function () {
        this.peripherals = this.getThingsStatus(this.config)
    },
    watch: {
        config: function (config) {
            this.peripherals = this.getThingsStatus(config)
        }
    },
    methods: {
        getThingsStatus: function (gatewayConfig) {
            gatewayConfig = gatewayConfig || {};
            const peripherals = [];
            for (let type in gatewayConfig) {
                const list = gatewayConfig[type];
                if (!Array.isArray(list)) {
                    continue;
                }

                for (let i = 0; i < list.length; i++) {
                    const item = list[i];
                    const peripheral = Object.assign({}, item)
                    peripheral.type = type;
                    peripheral.index = peripherals.length;
                    peripherals.push(peripheral)
                }
            }

            return peripherals;
        },
        loadGatewayConfig: function () {
            const self = this
            const url = "/config/gateway";
            ajax.get(url, function (result) {
                self.config = result || {}
            });

            return false;
        },
        loadThingsStatus: function () {
            const self = this
            const url = "/status/gateway/things";
            ajax.get(url, function (result) {
                self.things = result || {}
            });
        },
        onRefreshClick: function () {
            this.things = null;
            this.loadGatewayConfig();
            this.loadThingsStatus();
        }
    }
}

Vue.component('things-block', ThingsBlockComponent);

const LogsBlockComponent = {
    extends: BaseSettingBlock,
    template: '#logs-block-template',
    data: function () {
        return {
            logs: null,
            config: null
        }
    },
    mounted: function () { },
    methods: {
        loadSystemLogs: function () {
            const self = this
            const url = "/system/logs";
            ajax.get(url, function (result) {
                if (!result || result.error) {
                    self.logs = [];

                    self.showErrorResult(result);
                    return;
                }

                const data = result.logs;
                if (!Array.isArray(data)) {
                    self.logs = [];
                    return;
                }

                const names = ['date', 'time', 'level', 'file', 'message'];
                const logs = [];
                for (let i = data.length - 1; i >= 0; i--) {
                    const line = data[i]
                    if (!line) {
                        continue;
                    }

                    const log = {}
                    let start = 0;
                    for (let j = 0; j < 4; j++) {
                        let pos = line.indexOf(',', start);

                        if (pos >= start) {
                            const name = names[j]
                            const value = line.substr(start, pos - start)
                            log[name] = value;
                            start = pos + 1;
                        }
                    }

                    log.message = line.substr(start);
                    logs.push(log);
                }

                self.logs = logs;
            });
        },
        loadLogConfig: function () {
            const self = this
            const url = "/config/log";
            this.onConfigLoad(url, function(result) {
                self.config = result;
            });

            return false;
        },
        onLogConfigSave: function (name, config) {
            config = config || {}
            const self = this
            config.updated = Date.now();
            const data = JSON.stringify(config);

            const url = '/config/' + name;
            this.onConfigSave(url, data, function (result) { });
        },
        onRefreshClick: function () {
            this.logs = null;
            this.loadSystemLogs();
            this.loadLogConfig();
        },
        onStartDebugClick: function () {
            const log = this.log || {}
            log.level = 0;

            this.onLogConfigSave('log', log);

        },
        onStopDebugClick: function () {
            const log = this.log || {}
            log.level = 1;

            this.onLogConfigSave('log', log);
        }
    }
}

Vue.component('logs-block', LogsBlockComponent);

const StatusBlockComponent = {
    extends: BaseSettingBlock,
    template: '#status-block-template',
    data: function () {
        return {}
    },
    methods: {
        onStatusClick(url) {
            const self = this;
            ajax.get(url, function (result) {
                self.showResultMessage(result)
            });
        }
    }
}

Vue.component('status-block', StatusBlockComponent);

const ConfigApplication = {
    el: '#app-block',
    data: {
        currentTab: null,
        lang: {},
        showLeftNavbar: true,
        showMenu: false,
        systemOptions: {}
    },
    mounted: function () {
        const query = $wot.parseQueryString();
        this.currentTab = query.tab || 'overview'

        const defaultLang = $wot.langs['en-US'] || {};
        this.lang = Object.assign({}, defaultLang, $wot.langs['zh-CN']);

        const self = this;
        window.onpopstate = function (event) {
            const state = event.state;
            const tab = state && state.tab;
            if (tab) {
                self.currentTab = tab;
            }
        }

        this.loadSystemOptions();
    },
    methods: {
        loadSystemOptions: function () {
            const self = this
            const url = "/system/options";
            ajax.get(url, function (result) {
                if (!result || result.error) {
                    self.systemOptions = {};

                    self.showErrorResult(result);
                    return;
                }

                self.systemOptions = result || {};
            });
        },
        onLogoutClick: function () {
            const message = this.lang.tip_exit;
            if (!window.confirm(message)) {
                return
            }

            const url = "/auth/logout";
            ajax.post(url, {}, function (result) {
                location.href = 'login.html'
            });
        },
        onTabClick: function (tab) {
            if (!tab) {
                return;
            }

            this.currentTab = tab;

            const query = $wot.parseQueryString()
            const params = Object.assign({}, query)
            params.tab = tab
            const queryString = '?' + $wot.param(params);
            history.pushState({ tab: tab }, null, queryString);

            const self = this;
            this.$nextTick(function () {
                const block = self.$refs[tab + 'Block'];
                if (block && block.onRefreshClick) {
                    block.onRefreshClick();
                }
            });
        }
    }
}

$wot.init = function () {
    setTimeout(function () {
        const $app = new Vue(ConfigApplication);
        window.$app = $app;
    });
}
