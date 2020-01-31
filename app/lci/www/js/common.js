var VISION_VERSION = 100001

///////////////////////////////////////////////////////////////////////////////
// Misc

//;(function($) {

$.format = {};

$.format.formatFloat = function (value, n) {
	if (!value) {
		return 0.0;
	}

    var count = n || 2;
    return value.toFixed(count);
};

$.format.formatBytes = function (value) {
	if (typeof value == "undefined") {
		return "";

	} else if (value < 1024) {
		return value + " Bytes";

	} else if (value < 1024 * 1024) {
		return this.formatFloat(value / 1024) + " KB";

	} else if (value < 1024 * 1024 * 1024) {
		return this.formatFloat(value / (1024 * 1024)) + " MB";
	
	} else {
		return this.formatFloat(value / (1024 * 1024 * 1024)) + " GB";
	}
};

$.fn.extend({  
    "serializeWithCheckbox": function () {  
        var $f = $(this);  
        var data = $(this).serialize();  
        var $chks = $(this).find(":checkbox:not(:checked)");

        if ($chks.length == 0) {  
            return data;  
        }
        
        var nameArr = [];  
        var tempStr = "";  
        $chks.each(function () {  
            var chkName = $(this).attr("name");   
            if ($.inArray(chkName, nameArr) == -1 && $f.find(":checkbox[name='" + chkName + "']:checked").length == 0) {  
                nameArr.push(chkName);  
                tempStr += "&" + chkName + "=";  
            }  
        });

        data += tempStr;  
        return data;  
    }  
}); 

///////////////////////////////////////////////////////////////////////////////
// Form

$.form = {};

$.form.init = function(values, form) {
	var paramValues = values || params || {};

	var frm = form || document.forms[0];
	for (var paramName in paramValues) {
		$.form.setElementValue(frm, paramName, paramValues[paramName]);
	}
};

$.form.setElementValue = function (form, name, value) {
	try {
		if (!form) {
			return;
		}

		var item = form[name];
		if (!item) {
			return;
		}

		if (!item.tagName) {				
			for (var i = 0; i < item.length; i++) {
				var radio = item[i];
				if (radio && radio.value == value) {
					radio.checked = true;
					break;
				}
			}
			
		} else if (item.type == "checkbox") {
			item.checked = (value == item.value);

		} else {
			item.value = value || "";
		}
	} catch (e) {
	}
};


///////////////////////////////////////////////////////////////////////////////
// Language

if (typeof localStorage == 'undefined') {
	localStorage = {}
}

///////////////////////////////////////////////////////////////////////////////
// misc

function OnLogout() {
	if (!window.confirm('Are you sure want to exit?')) {
		return
	}

	var url = "/auth/logout";
	$.post(url, {}, function(result) {
		location.href = 'login.html'
	});
}

var $wot = {}

/**
 * 解析指定的 URL 的 Query 部分
 * @param {string} urlString 要解析的 URL 字符串, 未指定则默认为 location.search
 * @returns {object}
 */
$wot.parseQueryString = function (urlString) {
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
};
