(function () {

	'use strict'; // needed to support `apply`/`call` with `undefined`/`null`

	if (typeof Object.assign != 'function') {
		// Must be writable: true, enumerable: false, configurable: true
		Object.defineProperty(Object, "assign", {
			value: function assign(target, varArgs) { // .length of function is 2
				'use strict';
				if (target == null) { // TypeError if undefined or null
					throw new TypeError('Cannot convert undefined or null to object');
				}

				let to = Object(target);

				for (var index = 1; index < arguments.length; index++) {
					var nextSource = arguments[index];

					if (nextSource != null) { // Skip over if undefined or null
						for (let nextKey in nextSource) {
							// Avoid bugs when hasOwnProperty is shadowed
							if (Object.prototype.hasOwnProperty.call(nextSource, nextKey)) {
								to[nextKey] = nextSource[nextKey];
							}
						}
					}
				}
				return to;
			},
			writable: true,
			configurable: true
		});
	}
	
	if (!String.prototype.trim) {
		String.prototype.trim = function () {
			return this.replace(/^[\s\uFEFF\xA0]+|[\s\uFEFF\xA0]+$/g, '');
		};
	}

	if (!String.prototype.endsWith) {
		String.prototype.endsWith = function (search, this_len) {
			if (this_len === undefined || this_len > this.length) {
				this_len = this.length;
			}
			return this.substring(this_len - search.length, this_len) === search;
		};
	}

	// https://github.com/uxitten/polyfill/blob/master/string.polyfill.js
	// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/padStart
	if (!String.prototype.padStart) {
		String.prototype.padStart = function padStart(targetLength, padString) {
			targetLength = targetLength >> 0; //floor if number or convert non-number to 0;
			padString = String((typeof padString !== 'undefined' ? padString : ' '));
			if (this.length > targetLength) {
				return String(this);
			}
			else {
				targetLength = targetLength - this.length;
				if (targetLength > padString.length) {
					padString += padString.repeat(targetLength / padString.length); //append to original to ensure we are longer than needed
				}
				return padString.slice(0, targetLength) + String(this);
			}
		};
	}

	// https://github.com/uxitten/polyfill/blob/master/string.polyfill.js
	// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/padEnd
	if (!String.prototype.padEnd) {
		String.prototype.padEnd = function padEnd(targetLength, padString) {
			targetLength = targetLength >> 0; //floor if number or convert non-number to 0;
			padString = String((typeof padString !== 'undefined' ? padString : ''));
			if (this.length > targetLength) {
				return String(this);
			}
			else {
				targetLength = targetLength - this.length;
				if (targetLength > padString.length) {
					padString += padString.repeat(targetLength / padString.length); //append to original to ensure we are longer than needed
				}
				return String(this) + padString.slice(0, targetLength);
			}
		};
	}

	/*! http://mths.be/startswith v0.2.0 by @mathias */
	if (!String.prototype.startsWith) {
		var defineProperty = (function () {
			// IE 8 only supports `Object.defineProperty` on DOM elements
			try {
				var object = {};
				var $defineProperty = Object.defineProperty;
				var result = $defineProperty(object, object, object) && $defineProperty;
			} catch (error) { }
			return result;
		}());

		var toString = {}.toString;
		var startsWith = function (search) {
			if (this == null) {
				throw TypeError();
			}
			var string = String(this);
			if (search && toString.call(search) == '[object RegExp]') {
				throw TypeError();
			}
			var stringLength = string.length;
			var searchString = String(search);
			var searchLength = searchString.length;
			var position = arguments.length > 1 ? arguments[1] : undefined;
			// `ToInteger`
			var pos = position ? Number(position) : 0;
			if (pos != pos) { // better `isNaN`
				pos = 0;
			}
			var start = Math.min(Math.max(pos, 0), stringLength);
			// Avoid the `indexOf` call if no match is possible
			if (searchLength + start > stringLength) {
				return false;
			}
			var index = -1;
			while (++index < searchLength) {
				if (string.charCodeAt(start + index) != searchString.charCodeAt(index)) {
					return false;
				}
			}
			return true;
		};

		if (defineProperty) {
			defineProperty(String.prototype, 'startsWith', {
				'value': startsWith,
				'configurable': true,
				'writable': true
			});

		} else {
			String.prototype.startsWith = startsWith;
		}
	}

	if (!Number.parseInt) {
		Number.parseInt = parseInt;
	}

	if (!Number.parseFloat) {
		Number.parseFloat = parseFloat;
	}

	var type = function (value) {
		var result = typeof value
		if (result == 'object') {
			if (Array.isArray(value)) {
				return 'array'
			}
		}

		return result
	}

	var jsonpID = 0,
		document = window.document,
		key,
		name,
		rscript = /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi,
		scriptTypeRE = /^(?:text|application)\/javascript/i,
		xmlTypeRE = /^(?:text|application)\/xml/i,
		jsonType = 'application/json',
		htmlType = 'text/html',
		blankRE = /^\s*$/

	var ajax = function (options) {
		var settings = extend({}, options || {})
		for (key in ajax.settings) if (settings[key] === undefined) settings[key] = ajax.settings[key]

		ajaxStart(settings)

		if (!settings.crossDomain) settings.crossDomain = /^([\w-]+:)?\/\/([^\/]+)/.test(settings.url) &&
			RegExp.$2 != window.location.host

		var dataType = settings.dataType, hasPlaceholder = /=\?/.test(settings.url)
		if (dataType == 'jsonp' || hasPlaceholder) {
			if (!hasPlaceholder) settings.url = appendQuery(settings.url, 'callback=?')
			return ajax.JSONP(settings)
		}

		if (!settings.url) settings.url = window.location.toString()
		serializeData(settings)

		var mime = settings.accepts[dataType],
			baseHeaders = {},
			protocol = /^([\w-]+:)\/\//.test(settings.url) ? RegExp.$1 : window.location.protocol,
			xhr = ajax.settings.xhr(), abortTimeout

		if (!settings.crossDomain) baseHeaders['X-Requested-With'] = 'XMLHttpRequest'
		if (mime) {
			baseHeaders['Accept'] = mime
			if (mime.indexOf(',') > -1) mime = mime.split(',', 2)[0]
			xhr.overrideMimeType && xhr.overrideMimeType(mime)
		}
		if (settings.contentType || (settings.data && settings.type.toUpperCase() != 'GET'))
			baseHeaders['Content-Type'] = (settings.contentType || 'application/x-www-form-urlencoded')
		settings.headers = extend(baseHeaders, settings.headers || {})

		xhr.onreadystatechange = function () {
			if (xhr.readyState == 4) {
				clearTimeout(abortTimeout)
				var result, error = false
				if ((xhr.status >= 200 && xhr.status < 300) || xhr.status == 304 || (xhr.status == 0 && protocol == 'file:')) {
					dataType = dataType || mimeToDataType(xhr.getResponseHeader('content-type'))
					result = xhr.responseText

					try {
						if (dataType == 'script') (1, eval)(result)
						else if (dataType == 'xml') result = xhr.responseXML
						else if (dataType == 'json') result = blankRE.test(result) ? null : JSON.parse(result)
					} catch (e) { error = e }

					if (error) ajaxError(error, 'parsererror', xhr, settings)
					else ajaxSuccess(result, xhr, settings)
				} else {
					ajaxError(null, 'error', xhr, settings)
				}
			}
		}

		var async = 'async' in settings ? settings.async : true
		xhr.open(settings.type, settings.url, async)

		for (name in settings.headers) xhr.setRequestHeader(name, settings.headers[name])

		if (ajaxBeforeSend(xhr, settings) === false) {
			xhr.abort()
			return false
		}

		if (settings.timeout > 0) abortTimeout = setTimeout(function () {
			xhr.onreadystatechange = empty
			xhr.abort()
			ajaxError(null, 'timeout', xhr, settings)
		}, settings.timeout)

		// avoid sending empty string (#319)
		xhr.send(settings.data ? settings.data : null)
		return xhr
	}


	// trigger a custom event and return false if it was cancelled
	function triggerAndReturn(context, eventName, data) {
		//todo: Fire off some events
		//var event = $.Event(eventName)
		//$(context).trigger(event, data)
		return true;//!event.defaultPrevented
	}

	// trigger an Ajax "global" event
	function triggerGlobal(settings, context, eventName, data) {
		if (settings.global) return triggerAndReturn(context || document, eventName, data)
	}

	// Number of active Ajax requests
	ajax.active = 0

	function ajaxStart(settings) {
		if (settings.global && ajax.active++ === 0) triggerGlobal(settings, null, 'ajaxStart')
	}
	function ajaxStop(settings) {
		if (settings.global && !(--ajax.active)) triggerGlobal(settings, null, 'ajaxStop')
	}

	// triggers an extra global event "ajaxBeforeSend" that's like "ajaxSend" but cancelable
	function ajaxBeforeSend(xhr, settings) {
		var context = settings.context
		if (settings.beforeSend.call(context, xhr, settings) === false ||
			triggerGlobal(settings, context, 'ajaxBeforeSend', [xhr, settings]) === false)
			return false

		triggerGlobal(settings, context, 'ajaxSend', [xhr, settings])
	}
	function ajaxSuccess(data, xhr, settings) {
		var context = settings.context, status = 'success'
		settings.success.call(context, data, status, xhr)
		triggerGlobal(settings, context, 'ajaxSuccess', [xhr, settings, data])
		ajaxComplete(status, xhr, settings)
	}
	// type: "timeout", "error", "abort", "parsererror"
	function ajaxError(error, type, xhr, settings) {
		var context = settings.context
		settings.error.call(context, xhr, type, error)
		triggerGlobal(settings, context, 'ajaxError', [xhr, settings, error])
		ajaxComplete(type, xhr, settings)
	}
	// status: "success", "notmodified", "error", "timeout", "abort", "parsererror"
	function ajaxComplete(status, xhr, settings) {
		var context = settings.context
		settings.complete.call(context, xhr, status)
		triggerGlobal(settings, context, 'ajaxComplete', [xhr, settings])
		ajaxStop(settings)
	}

	// Empty function, used as default callback
	function empty() { }

	ajax.JSONP = function (options) {
		if (!('type' in options)) return ajax(options)

		var callbackName = 'jsonp' + (++jsonpID),
			script = document.createElement('script'),
			abort = function () {
				//todo: remove script
				//$(script).remove()
				if (callbackName in window) window[callbackName] = empty
				ajaxComplete('abort', xhr, options)
			},
			xhr = { abort: abort }, abortTimeout,
			head = document.getElementsByTagName("head")[0]
				|| document.documentElement

		if (options.error) script.onerror = function () {
			xhr.abort()
			options.error()
		}

		window[callbackName] = function (data) {
			clearTimeout(abortTimeout)
			//todo: remove script
			//$(script).remove()
			delete window[callbackName]
			ajaxSuccess(data, xhr, options)
		}

		serializeData(options)
		script.src = options.url.replace(/=\?/, '=' + callbackName)

		// Use insertBefore instead of appendChild to circumvent an IE6 bug.
		// This arises when a base node is used (see jQuery bugs #2709 and #4378).
		head.insertBefore(script, head.firstChild);

		if (options.timeout > 0) abortTimeout = setTimeout(function () {
			xhr.abort()
			ajaxComplete('timeout', xhr, options)
		}, options.timeout)

		return xhr
	}

	ajax.settings = {
		// Default type of request
		type: 'GET',
		// Callback that is executed before request
		beforeSend: empty,
		// Callback that is executed if the request succeeds
		success: empty,
		// Callback that is executed the the server drops error
		error: empty,
		// Callback that is executed on request complete (both: error and success)
		complete: empty,
		// The context for the callbacks
		context: null,
		// Whether to trigger "global" Ajax events
		global: true,
		// Transport
		xhr: function () {
			return new window.XMLHttpRequest()
		},
		// MIME types mapping
		accepts: {
			script: 'text/javascript, application/javascript',
			json: jsonType,
			xml: 'application/xml, text/xml',
			html: htmlType,
			text: 'text/plain'
		},
		// Whether the request is to another domain
		crossDomain: false,
		// Default timeout
		timeout: 0
	}

	function mimeToDataType(mime) {
		return mime && (mime == htmlType ? 'html' :
			mime == jsonType ? 'json' :
				scriptTypeRE.test(mime) ? 'script' :
					xmlTypeRE.test(mime) && 'xml') || 'text'
	}

	function appendQuery(url, query) {
		return (url + '&' + query).replace(/[&?]{1,2}/, '?')
	}

	// serialize payload and append it to the URL for GET requests
	function serializeData(options) {
		if (options.contentType == 'multipart/form-data') {
			return; // FormData
		}

		if (type(options.data) === 'object') options.data = param(options.data)
		if (options.data && (!options.type || options.type.toUpperCase() == 'GET'))
			options.url = appendQuery(options.url, options.data)
	}

	ajax.get = function (url, success) { return ajax({ url: url, success: success }) }

	ajax.post = function (url, data, success, dataType) {
		if (type(data) === 'function') dataType = dataType || success, success = data, data = null
		return ajax({ type: 'POST', url: url, data: data, success: success, dataType: dataType })
	}

	ajax.getJSON = function (url, success) {
		return ajax({ url: url, success: success, dataType: 'json' })
	}

	var escape = encodeURIComponent

	function serialize(params, obj, traditional, scope) {
		var array = type(obj) === 'array';
		for (var key in obj) {
			var value = obj[key];

			if (scope) key = traditional ? scope : scope + '[' + (array ? '' : key) + ']'
			// handle data in serializeArray() format
			if (!scope && array) params.add(value.name, value.value)
			// recurse into nested objects
			else if (traditional ? (type(value) === 'array') : (type(value) === 'object'))
				serialize(params, value, traditional, key)
			else params.add(key, value)
		}
	}

	function param(obj, traditional) {
		var params = []
		params.add = function (k, v) { this.push(escape(k) + '=' + escape(v)) }
		serialize(params, obj, traditional)
		return params.join('&').replace('%20', '+')
	}

	function extend(target) {
		var slice = Array.prototype.slice;
		slice.call(arguments, 1).forEach(function (source) {
			for (key in source)
				if (source[key] !== undefined)
					target[key] = source[key]
		})
		return target
	}

	window.ajax = ajax;
}());
