var $wot = { langs: {} };

var ActivateApplication = {
    el: '#app-block',
    data: {
        cloud: {},
        device: {},
        firmware: {},
        isActivated: false,
        lang: {},
        settings: {},
        update: {},
        updateStatus: null
    },
    mounted: function () {
        this.onSystemRead();

        const defaultLang = $wot.langs['en-US'] || {};
        this.lang = Object.assign({}, defaultLang, $wot.langs['zh-CN']);
    },
    methods: {
        onActivateSumbit: function () {
            var self = this;
            self.updateStatus = null;

            if (!self.onFormValidity()) {
                return
            }

            var data = {
                did: self.settings.did || '',
                base: self.settings.base || '',
                server: self.settings.server || '',
                secret: self.settings.secret || '',
                mqtt: self.settings.mqtt || '',
                serialNumber: self.settings.serialNumber || '',
                password: self.settings.password || ''
            }

            const lang = this.lang;
            const title = lang.activate_confirm || "Are you sure want to activate the device?";
            if (!window.confirm(title)) {
                return false;
            }

            var url = "/system/activate";
            self.updateStatus = lang.activate_activating;
            ajax.post(url, data, function (result) {
                if (!result || result.error) {
                    self.updateStatus = lang.activate_failed + ': ' + self.getErrorMessage(result);

                } else {
                    self.updateStatus = lang.activate_success;
                    setTimeout(function () {
                        location.href = '/?v=20200710';
                    }, 2000);
                }
            });

            return false;
        },

        onSystemRead: function () {
            var self = this;
            var url = "/system/activate";
            ajax.get(url, function (result) {
                if (!result || result.error) {
                    self.updateStatus = self.getErrorMessage(result);
                    return;
                }

                self.device = result.device || {}
                self.settings = result.settings || {}

                var activate = self.settings.activate
                if (activate === true || activate === 'true') {
                    self.isActivated = true;
                }
            });

            return false;
        },

        getErrorMessage: function (error) {
            if (!error) {
                return 'Unknown error'
            }

            var type = typeof error
            if (type == 'object') {
                return error.message || error.error || error.code || JSON.stringify(error)
            }

            return error
        },

        onFormValidity: function () {
            var self = this;
            function onFormItemValidity(element) {
                if (!element) {
                    return;
                }

                var validity = element.validity
                if (validity == null || validity.valid) {
                    element.setCustomValidity("");
                    return;
                }

                var message = '';
                if (validity.valueMissing) {
                    message = "Value is missing"
                }

                if (message) {
                    element.focus()
                    element.setCustomValidity(message);
                    throw message || 'invalid value';
                }

                element.focus();
            }

            try {
                var form = document.getElementById('activate-form');
                onFormItemValidity(form.password);

            } catch (error) {
                self.updateStatus = 'Validity failed, ' + self.getErrorMessage(error);
                return false;
            }

            return true;
        }
    }
}

$wot.init = function () {
    var app = new Vue(ActivateApplication);
    window.$app = app;
};