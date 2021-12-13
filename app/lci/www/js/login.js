var $wot = { langs: {} };

var LoginApplication = {
    el: '#app-block',
    data: {
        deviceInfo: null,
        error: { empty: false, invalid: false },
        lang: {},
        message: 'Gateway',
        showForgotTip: false
    },
    mounted: function() {
        this.loadDeviceInfo();

        const defaultLang = $wot.langs['en-US'] || {};
        this.lang = Object.assign({}, defaultLang, $wot.langs['zh-CN']);
    },
    methods: {
        loadDeviceInfo: function () {
            const self = this
            const url = "/device/info";
            ajax.get(url, function (result) {
                self.deviceInfo = result || {}
            });

            return false;
        },
        onUserLogin: function (username, password, callback) {
            var url = "/auth/login";
            var data = { username: username, password: password }
            ajax.post(url, data, function (result) {
                if (result.error) {
                    callback(result)

                } else {
                    callback(null, result)
                }
            });
        },
        onFormSubmit: function () {
            var form = document.forms[0];
            var username = 'admin'
            var password = form.password.value;

            $app.error = { loadding: true }
            if (!password) {
                $app.error = { empty: true }
                return false;
            }

            form.password.disabled = true;
            form.login_button.disabled = true;

            this.onUserLogin(username, password, function (err, result) {
                if (err) {
                    $app.error = { invalid: true }
                    form.password.disabled = false;
                    form.login_button.disabled = false;

                } else {
                    $app.error = {}
                    location.href = "/?v=20200710";
                }
            })

            return false;
        }
    }
}

$wot.init = function() {
    var app = new Vue(LoginApplication);
    window.$app = app;
};
