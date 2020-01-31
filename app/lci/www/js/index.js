var query = $wot.parseQueryString()

var $vueData = {
    net_mode: 'ppp',
    ip_mode: 'static',
    ip: '192.168.8.12',
    netmask: '255.255.255.0',
    router: '192.168.8.1',
    dns: '8.8.8.8 192.168.8.1',
    gateway: '',
    base: '',
    mqtt: '',
    status: {},
    update: {},
    register: {},
    firmware: {},
    network: [],
    currentTab: query.tab || 'overview',
    uploadStatus: null,
    responseData: null,
    updateStatus: null
}

var config = {

}

var app = new Vue({
    el: '#app',
    data: $vueData,
    watch: {
        currentTab: function(newValue) {
            var params = Object.assign({}, query)
            params.tab = newValue
            var queryString = '?' + $.param(params);
            history.replaceState(null, null, queryString);
        }
    }
})

function onGetSystemStatus() {
    var updateStates = ['INIT', 'DOWNLOADING', 'DOWNLOAD_COMPLETED', 'UPDATING'];
    var updateResult = ['INIT', 'SUCCESSFULLY', 'NOT_ENOUGH_FLASH', 'NOT_ENOUGH_RAM',
        'DISCONNECTED', 'VALIDATION_FAILED', 'UNSUPPORTED_FIRMWARE_TYPE', 'INVALID_URI',
        'FAILED', 'UNSUPPORTED_PROTOCOL'];
    var registerStates = ['UNREGISTER', 'REGISTER']

    var url = "/system/status";
    $.get(url, function (result) {

        setTimeout(function () {
            onGetSystemStatus();
        }, 2000)

        if (!result || result.error) {
            return;
        }

        var update = result.update || {};
        update.state = updateStates[update.state] || update.state;
        update.result = updateResult[update.result] || update.result;

        var register = result.register || {};
        register.state = registerStates[register.state] || register.state;
        register.updated = Date.now() - (Number.parseInt(register.updated) || 0);
        register.updated = Math.floor(register.updated / 1000);

        $vueData.status = result.system || {}
        $vueData.register = register || {}
        $vueData.update = update || {}
        $vueData.firmware = result.firmware || {}
        $vueData.network = result.network || []
    });

    return false;
}

function onGetNetworkConfig() {
    var url = "/config/network";
    $.get(url, function (result) {
        if (!result || result.error) {
            return;
        }
        $vueData.net_mode = result.net_mode
        $vueData.ip_mode = result.ip_mode
        $vueData.ip = result.ip
        $vueData.netmask = result.netmask
        $vueData.router = result.router
        $vueData.dns = result.dns
        $vueData.base = result.base
        $vueData.mqtt = result.mqtt

        config.network = result
    });

    return false;
}

function onGetUserConfig() {
    var url = "/config/user";
    $.get(url, function (result) {
        if (!result || result.error) {
            return;
        }

        $vueData.gateway = JSON.stringify(result, null, '\t')
        config.gateway = result
    });

    return false;
}

function onPostUserConfig() {
    try {
        var result = JSON.parse($vueData.gateway)
        $.ajax({
            url: '/config/user',
            data: $vueData.gateway,
            type: 'post',
            cache: false,
            processData: false,
            contentType: 'application/json',
            success: function (result) {
                var message = 'Save Done: \n'
                message += JSON.stringify(result, null, '  ');
                alert(message)
            },
            error: function (result) {
                var message = 'Save Error. Please try again later: \n'
                message += JSON.stringify(result, null, '  ');
                alert(message)
            }
        })

    } catch (e) {
        alert('Invalid JSON format: ' + (e || e.message))
    }
}

function onConfigReset() {
    var result = config.network || {}

    $vueData.net_mode = result.net_mode
    $vueData.ip_mode = result.ip_mode
    $vueData.ip = result.ip
    $vueData.netmask = result.netmask
    $vueData.router = result.router
    $vueData.dns = result.dns
    $vueData.base = result.base
    $vueData.mqtt = result.mqtt
}

function onFormItemValidity(element) {
    var value = element.value;
    var message = '';
    if (element.required) {
        if (value == null || value == '') {
            message = 'Value is missing'
        }
    }

    var format = element.dataset.format;
    if (format) {
        if (format == 'ip' && !isIpAddress(value)) {
            message = 'Invalid IP address'
        } else if (format == 'ips' && !isIpAddressList(value)) {
            message = 'Invalid IP address list'
        }
    }

    if (message) {
        alert(message);
        element.focus();
        throw 'test';
    }
}

function onFormValidity(form) {
    try {
        var form = $("#network-form").get(0);
        onFormItemValidity(form.ip);
        onFormItemValidity(form.netmask);
        onFormItemValidity(form.router);
        onFormItemValidity(form.dns);

    } catch (e) {
        console.log(e);
        return false;
    }

    return true;
}

function isIpAddress(address) {
    if (!address) {
        return false;
    }

    var pattern = /^((25[0-5]|2[0-4]\d|((1\d{2})|([1-9]?\d)))\.){3}(25[0-5]|2[0-4]\d|((1\d{2})|([1-9]?\d)))$/;
    return pattern.test(address)
}

function isIpAddressList(value) {
    if (!value) {
        return false;
    }
    var tokens = value.split(' ')
    for (var i = 0; i < tokens.length; i++) {
        if (!isIpAddress(tokens[i])) return false;
    }

    return true;
}

function onConfigWrite(callback) {
    if (!onFormValidity()) {
        return;
    }

    $("#network-form").submit();
}

function onConfigSubmit() {
    var url = "/config/network";

    var data = {
        base: $vueData.base,
        mqtt: $vueData.mqtt,
        router: $vueData.router,
        dns: $vueData.dns,
        netmask: $vueData.netmask,
        ip: $vueData.ip,
        ip_mode: $vueData.ip_mode,
        net_mode: $vueData.net_mode
    }

    if (data.ip_mode == "static") {
        if (!isIpAddress(data.ip)) {
            alert('Invalid IP Address')
            return;
        }
    }

    $.post(url, data, function (result) {
        if (!result || result.error) {
            alert('Failed to save. Please try again later');

        } else {
            alert('Save successfully');
        }
    });

    return false;
}

function onSystemUpload() {
    if ($vueData.uploadStatus) {
        return;
    }
    
    $vueData.uploadStatus = 'Uploading, please wait...'
    $vueData.responseData = null

    var form = document.getElementById('firmware-form')
    var formData = new FormData(form);
    $.ajax({
        url: '/upload',
        data: formData,
        type: 'post',
        cache: false,
        processData: false,
        contentType: 'multipart/form-data',
        success: function (result) {
            $vueData.uploadStatus = null;
            var message = 'Upload Done: \n'
            message += JSON.stringify(result, null, '  ');
            $vueData.responseData = message
        },
        error: function (result) {
            $vueData.uploadStatus = null;
            var message = 'Upload Error. Please try again later: \n'
            message += JSON.stringify(result, null, '  ');
            $vueData.responseData = message
        }
    })
}

function showResult(result, message) {
    if (!message) {
        if (!result || result.error) {
            message = ('Failed! Please try again later');
            message += ':\r\n'

        } else {
            message = ''
        }
    }

    if (result && result.output) {
        message += result.output;
    } else {
        message += JSON.stringify(result, null, '  ');
    }

    $vueData.responseData = message
}

function onSystemUpdate() {
    var url = "/system/action";
    var data = { update: 1 };

    $vueData.responseData = null
    $vueData.updateStatus = 'Updating, please wait...'
    $.post(url, data, function (result) {
        $vueData.updateStatus = null;
        showResult(result)
    });

    return false;
}

function onSystemUpgrade() {
    if (!window.confirm("Are you sure want to upgrade the device?")) {
        return;
    }

    var url = "/system/action";
    var data = { upgrade: "system" }

    $vueData.responseData = null
    $vueData.updateStatus = 'Upgrading, please wait...'
    $.post(url, data, function (result) {
        $vueData.updateStatus = null
        showResult(result)
    });

    return false;
}

function onSystemReboot() {
    if (!window.confirm("Are you sure want to reboot the device?")) {
        return;
    }

    var url = "/system/action";
    var data = { reboot: 5 }
    $vueData.responseData = null

    $.post(url, data, function (result) {
        var message = ''
        if (!result || result.error) {
            message = ('Failed to reboot. Please try again later');

        } else {
            message = ('Device will reboot in 5 seconds');
        }

        showResult(result, message)
    });

    return false;
}

function onSystemReset() {
    if (!window.confirm("Are you sure want to reset the device?")) {
        return;
    }

    var url = "/system/action";
    var data = { reset: 3 }

    $vueData.responseData = null
    $.post(url, data, function (result) {
        var message = ''        
        showResult(result, message)

        if (!(!result || result.error)) {
            location.href = '/'
        }
    });

    return false;
}

function onSystemInstall() {
    if ($vueData.uploadStatus) {
        return;

    } else if (!window.confirm("Are you sure want to install the uploaded firmware?")) {
        return;
    }

    var url = "/system/action";
    var data = { install: 3 }

    $vueData.uploadStatus = 'Installing, please wait...'
    $vueData.responseData = null

    $.post(url, data, function (result) {
        $vueData.uploadStatus = null;
        showResult(result)
    });

    return false;
}

$(document).ready(function () {
    $('#logout_item').click(OnLogout);

    onGetNetworkConfig();
    onGetUserConfig();
    onGetSystemStatus();

    /**
    setInterval(function () {
        onGetSystemStatus();
    }, 100)
    */
});
