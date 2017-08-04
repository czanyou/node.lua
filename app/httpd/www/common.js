var VISION_VERSION = 100001

String.prototype.trim = function() {
	return this.replace(/(^\s*)|(\s*$)/g, "");  
}

String.prototype.startsWith = function (str){
	return this.slice(0, str.length) == str;
};

///////////////////////////////////////////////////////////////////////////////
// Misc

//;(function($) {

$.parseInt = function (value, defaultValue) {
	if (typeof(value) == 'number') {
		return value;

	} else if (!value) {
		return defaultValue;
	}

	try {
		if (typeof(value) == 'string') {
			return parseInt(value);
		}
	} catch (e) {
	}
	return defaultValue;
};

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

$.form.isIpAddress = function (address, flags) {
	try {
		if (!address && flags) {
			return true;
		}

		var tokens = address.split(".");
		if (tokens.length != 4) {
			return false;
		}

		for (var i = 0; i < 4; i++) {
			if (tokens[i].length > 3) {
				return false;
			}
			var value = parseInt(tokens[i]);
			if (value < 0 || value > 255 || (value + "") != tokens[i]) {
				return false;
			}
		}

		return true;
	} catch (e) {
	}
	return false;
}

$.form.nextElement = function (obj) {
	var node = obj ? obj.nextSibling : null;
	while (node && node.nodeType != 1) {
		node = node.nextSibling;
	}
	return node;
}

$.form.showTip = function (input, isRight, text) {
	if (isRight) {
		$(input).removeClass("value-invalid");
	} else {
		$(input).addClass("value-invalid");
	}
}

function validateIPAddress(input, flags) {
	$.form.showTip(input, $.form.isIpAddress(input.value, flags), T("IPErrorAddress"));
}

///////////////////////////////////////////////////////////////////////////////
// Language

if (typeof localStorage == 'undefined') {
	localStorage = {}
}

$.lang = {};

$.lang.select = function (lang) {
	localStorage['lang'] = lang
	location.reload();
}

$.lang.name = function () {
	var lang = localStorage['lang']
	if (!lang || lang == "undefined") {
		// IE accepts "navigator.userLanguage" while Gecko "navigator.language".
		if (navigator.userLanguage) {
			lang = navigator.userLanguage.toLowerCase();

		} else if (navigator.language) {
			lang = navigator.language.toLowerCase();

		} else {
			// Firefox 1.0 PR has a bug: it doens't support the "language" property.
			lang = "en";
		}
		
		// Some language codes are set in 5 characters, 
		// like "pt-br" for Brasilian Portuguese.
		if (lang.length >= 5) {
			lang = lang.substr(0, 5) ;
		}
	}

	if (lang != "zh-cn") {
		lang = "en";
	}

	return lang;
};

function T(key, defaultText) {
	if (!key) {
		return defaultText || "";
	}
	try {
		return VisionLang[key] || defaultText || key || "";
	} catch (e) {}
	return defaultText || key || "";
}

function $translate(element) {
	var html = element.innerHTML
	html = html.replace(/\$\{([^}]+)\}/g, function(word, key) {
		return T(key, key)
	})

	element.innerHTML = html

	$(element).show()
}

$.lang.update = function(type, data) {
	if (!VisionLang) {
		return
	}

	var list = {}
	if ($.lang.locale == type) {
		list = data
	}

	for (key in list) {
		var value = list[key];
		VisionLang[key] = value;
	}
}


$.lang.locale = $.lang.name();
document.documentElement.className = $.lang.locale;
document.documentElement.lang = $.lang.locale;
document.write('<script src="/lang.js?v=' + VISION_VERSION + '"></script>');

///////////////////////////////////////////////////////////////////////////////
// misc

function OnLogout() {
	if (!window.confirm(T("UserLogoutConfirm"))) {
		return
	}

	var url = "/api.lua?api=/logout";
	$.get(url, function(result) {
		location.href = 'login.html'
	});
}

///////////////////////////////////////////////////////////////////////////////
// Index


function OnLeftMenuItemClick() {
	$("#sidebar").addClass('sidebar-hide')
	$("#container").fadeIn()

	var current = this;
	$("#left_menu_list a").each(function() {
		if (current != this) {
			$(this).removeClass("selected");
		}                
	});
	$(this).addClass("selected");

	var page = $(this).attr("href") || "";
	location.hash = page.substring(1);

	return false;
}

function OnLeftMenuDefaultItem(hash) {
	var $defaultItem = null;
	var $selectdItem = null;

	$("#left_menu_list a").each(function() {
		if (!$defaultItem) {
			$defaultItem = $(this);
		}

		var src = $(this).attr("href") || "";
		if (src == ('#' + hash)) {
			$selectdItem = $(this);
		}
	});

	return $selectdItem || $defaultItem;
}

function OnLeftMenuHashChange() {
	var hash = location.hash || "";
	hash = hash.substring(1);

	var $defaultItem = OnLeftMenuDefaultItem(hash);

	if ($defaultItem) {
		$defaultItem.addClass("selected");

		var src = $defaultItem.attr("href") || "";
		src = src.substring(1) + ".html"

		$("#frame-content").attr("src", src);
	}
}

function OnLeftMenuPageResize() {
	var viewHeight = $(window).height();
	var height = viewHeight - 5;
}

function OnLeftMenuClick() {
	$("#sidebar").removeClass('sidebar-hide')
	$("#container").fadeOut()
}

function OnLeftMenuInit() {
	$("#left_menu_list a").click(OnLeftMenuItemClick);

	OnLeftMenuPageResize();

	var viewWidth = $(window).width();
	if (viewWidth >= 600) {
		OnLeftMenuHashChange();
	}

	$("#container-header").click(OnLeftMenuClick)
}

function OnAppStatusGetDetailHTML(data) {
	var html = '<dl>'

	html += '<dd><img src="/app/'
	html += data.name
	html += '/icon.png?q='
	html += data.version
	html += '"/></dd>'

	html += '<dt>' + T('Name') + ':</dt><dd>'
	html += data.name
	html += '</dd>'

	html += '<dt>' + T('DisplayName') + ':</dt><dd>'
	html += data.title
	html += '</dd>'

	html += '<dt>' + T('Version') + ':</dt><dd>'
	html += data.version
	html += '</dd>'

	html += '<dt>' + T('Description') + ':</dt><dd>'
	html += data.description
	html += '</dd>'

	html += '</dl>'
	return html
}

function OnAppStatusPageLoad() {
	var url = "/api.lua?api=/application/info&path=" + location.pathname;
	$.get(url, function(data) {
		$("#main-inner").html(OnAppStatusGetDetailHTML(data))
	});
}


