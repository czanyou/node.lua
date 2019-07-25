(function () {

'use strict'; // needed to support `apply`/`call` with `undefined`/`null`

if (!String.prototype.trim) {
  String.prototype.trim = function () {
    return this.replace(/^[\s\uFEFF\xA0]+|[\s\uFEFF\xA0]+$/g, '');
  };
}

if (!String.prototype.endsWith) {
	String.prototype.endsWith = function(search, this_len) {
		if (this_len === undefined || this_len > this.length) {
			this_len = this.length;
		}
		return this.substring(this_len - search.length, this_len) === search;
	};
}

// https://github.com/uxitten/polyfill/blob/master/string.polyfill.js
// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/padStart
if (!String.prototype.padStart) {
    String.prototype.padStart = function padStart(targetLength,padString) {
        targetLength = targetLength>>0; //floor if number or convert non-number to 0;
        padString = String((typeof padString !== 'undefined' ? padString : ' '));
        if (this.length > targetLength) {
            return String(this);
        }
        else {
            targetLength = targetLength-this.length;
            if (targetLength > padString.length) {
                padString += padString.repeat(targetLength/padString.length); //append to original to ensure we are longer than needed
            }
            return padString.slice(0,targetLength) + String(this);
        }
    };
}

// https://github.com/uxitten/polyfill/blob/master/string.polyfill.js
// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/padEnd
if (!String.prototype.padEnd) {
    String.prototype.padEnd = function padEnd(targetLength,padString) {
        targetLength = targetLength>>0; //floor if number or convert non-number to 0;
        padString = String((typeof padString !== 'undefined' ? padString: ''));
        if (this.length > targetLength) {
            return String(this);
        }
        else {
            targetLength = targetLength-this.length;
            if (targetLength > padString.length) {
                padString += padString.repeat(targetLength/padString.length); //append to original to ensure we are longer than needed
            }
            return String(this) + padString.slice(0,targetLength);
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

}());
