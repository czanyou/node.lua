<?php

# markdown to html
# ======
# 

define('S_ROOT', dirname(dirname(__FILE__)));    ///< System Root Path

date_default_timezone_set('PRC');

global $Q;

# Query seed
# 通过修改这个值来实现更新浏览器缓存的功能
$Q = date("Ymd") . 100014;

# 
require_once('assets/Parsedown.class.php');


/**
 * 一个安全的取得一个数组或者对象的指定的名称的属性的值的方法.
 * @param object 一个对象或者数组
 * @param name 要查询的属性的名称
 * @param default 如果指定的属性不存在, 返回的默认值.
 * @author chengzhen (anyou@msn.com)
 */
function safe_get($object, $name, $default = null) {
    if (is_array($object)) {
        return (isset($object[$name])) ? $object[$name] : $default;

    } else if (is_object($object)) {
        return (isset($object->$name)) ? $object->$name : $default;

    } else {
        return $default;
    }
}

// ------------------------------------------------------------
// context menu

function md_add_toc($parser, $text) {

    $headers = array();
    $lastLevel = 1;

    $headerCount = 0;

    $headers[] = '<div class="toc">';
    $headers[] = '<ul class="l1">';

    foreach ($parser->headers as $header) {
        $element = $header["element"];
        $level   = $element['level'];
        $name    = $element['text'];
        $index   = $element['index'];

        $indent = '';
        for ($i = 1; $i < $level; $i++) {
            $indent .= '  ';
        }

        //echo $level, " - ", $name, "\r\n";
        if ($level > $lastLevel) {
            for ($i = $lastLevel; $i < $level; $i++) {
                $headers[] = $indent . '<ul class="l' . ($i + 1) .'"> ';
            }

        } else if ($level < $lastLevel) {
            for ($i = $level; $i < $lastLevel; $i++) {
                $headers[] = $indent . '</ul>';
            }
        }

        $lastLevel = $level;

        $headerCount++;
        $headers[] = $indent . '<li>' . '<a href="#h' . $index . '">' . $name . '</a></li>';
    }

    for ($i = 1; $i < $lastLevel; $i++) {
        $headers[] = '</ul>';
    }

    $headers[] = '</ul>';
    $headers[] = '</div>';

    if ($headerCount > 0) {
        $menuText =  join("\r\n", $headers);
        $text = str_replace("[TOC]", $menuText, $text);
    }

    return $text;
}


function md_load($page, $file) {
    $filename = S_ROOT . "/" . $page . "/" . $file;
    if (!file_exists($filename)) {
        return "File not found: " . $filename . "\r\n";
    }

    $fileData       = implode('', file($filename));
    $parser         = Parsedown::instance();
    $articleHtml    = $parser->text($fileData);
    $articleHtml    = md_add_toc($parser, $articleHtml);

    return $articleHtml;
}

function md_head($title) {
    global $Q;
?>
<head>
    <meta http-equiv="mobile-agent" content="format=html5;"/>
    <meta http-equiv="content-type" content="text/html; charset=utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"/>
    <title><?=$title?></title>
    <link rel="stylesheet" href="assets/css/bootstrap.min.css?q=<?=$Q?>" />
    <link rel="stylesheet" href="assets/css/highlight.css?q=<?=$Q?>">
    <link rel="stylesheet" href="assets/css/style.css?q=<?=$Q?>" />
    <link href="favicon.ico?q=<?=$Q?>" rel="shortcut icon">
    <script src="assets/js/jquery.js?q=<?=$Q?>"></script>
    <script src="assets/js/tether.min.js?q=<?=$Q?>"></script>
    <script src="assets/js/bootstrap.min.js?q=<?=$Q?>"></script>
    <script src="assets/js/raphael.js?q=<?=$Q?>"></script>
    <script src="assets/js/underscore.js?q=<?=$Q?>"></script>
    <script src="assets/js/sequence-diagram.js?q=<?=$Q?>"></script>
    <script src="assets/js/flowchart.min.js?q=<?=$Q?>"></script>
    <script src="assets/js/highlight.js?q=<?=$Q?>"></script>
</head>

<?php

}


function md_main_nav($title, $nav) {
    global $Q;
?><a class="logo" href="/">
      <img src="assets/images/logo.png?q=<?=$Q?>.1" alt="logo"
      /><span><?=$title?></span></a>
    <nav id="header-nav">
<?php
    foreach ($nav as $item) {
        $name = $item[0];
        $file = $item[1];
        $text = $item[2];
        echo '      <a name="', $name, '" href="?p=', $name, '&f=', $file, '.md&q=', $Q, '">', $text, '</a>', "\r\n";
    }
?>    </nav>
<?php
}

function md_main_frame($page, $file, $title, $nav) {

?>
<script>
    var page = "<?=$page?>";
    var file = "<?=$file?>";

   function query_param(url, name) {
        var search = url.split('?')[1]
        if (!search) {
            return undefined;
        }
     
        var tokens = search.split('&');
        for (var i = 0; i < tokens.length; i++) {
            if (tokens[i].split('=')[0] == name) {
                return decodeURI(tokens[i].split('=')[1]);
            }
        }
        return undefined;
        
    };

    function on_frame_reload(file) {
        var url = location.pathname + '?p=' + page + '&f=' + file;
        $("#iframe").attr('src', url + '&m=embed').show()
        return url
    }

    function on_frame_load() {
        // get the current url of the iframe
        var iframe = parent.document.getElementById("iframe")
        var href = iframe.contentWindow.location.href 
        var f = query_param(href, 'f')
        if (!f) {
            return
        }

        var url = location.pathname + '?p=' + page + '&f=' + f;
        history.replaceState(null, "", url);

        // highlight current left menu item
        $(".leftmenu a").each(function() {
            var $this = $(this)
            var href = $this.attr('href')
            if (f == (href + '.md')) {
                $this.addClass('toc-current')

            } else {
                $this.removeClass('toc-current')
            }
        })
    }

    $(document).ready(function() {

        // highlight current header menu item
        $("#header-nav a").each(function() {
            var $this = $(this)
            if ($this.attr('name') == page) {
                $this.addClass('current')
            }
        })

        // load default page
        on_frame_reload(file)

        // bind leftmenu click event
        $(".leftmenu a").each(function() {
            var file = $(this).attr('href');

            $(this).click(function() {
                var url = on_frame_reload(file + '.md')
                history.replaceState(null, "", url);

                return false;
            })
        })

    })

</script>

<header id="header" class="header">
  <div id="header-inner" class="header-inner">
    <?php md_main_nav($title, $nav); ?>
  </div>
</header>

<div id="wrapper"><div class="main-wrapper">
  <?php require_once($page . '/menu.html') ?>

  <div class="post">
    <iframe id="iframe" name="iframe" onload="on_frame_load()"></iframe>
  </div>
</div></div>

<?php

}

function md_sub_frame($page, $file) {
?>
<script>

    var currentTitle = null

    function init_sequence_diagram() {
        try {
            var seq = $(".language-seq");
            if (seq && seq.sequenceDiagram) {
                seq.sequenceDiagram({theme: 'simple'});
            }
        } catch (e) {
            console.log(e)
        }
    }


    $(document).ready(function() {
        // init sequence diagram
        init_sequence_diagram()
        
        // highlight language
        hljs.initHighlighting();
        $('pre code').each(function(i, block) {
            hljs.highlightBlock(block);
        });

        var contents = $('h1,h2,h3,h4,h5,h6')

        // highlight current right menu item
        function on_title_hover(title) {
            $(".toc a").each(function() {
                var href = this.href || ''
                href = href.split('#')[1]

                if (href == title.id) {
                    $(this).addClass('toc-current')
                } else {
                    $(this).removeClass('toc-current')
                }
            })
        }

        $(window).scroll(function () {
            var viewTop = Math.max(document.body.scrollTop, 
                document.documentElement.scrollTop);

            // highlight current right menu item
            contents.each(function (index, el) {
                var top = $(this).offset().top
                if (top >= viewTop) {
                    if (currentTitle != this) {
                        currentTitle = this
                        on_title_hover(this)
                    }
                    return false
                }
            })
        });
    });
</script>

<div id="article" class="article">
  <?= md_load($page, $file); ?>
</div>

<footer id="footer" class="footer">
  <div id="backtop-wrapper"><a href="#">返回顶部</a></div>
</footer>

<?php

}

function md_print_docs($page, $file, $title, $nav) {
    $file  = safe_get($_GET, 'f', $file);
    $page  = safe_get($_GET, 'p', $page);

?>
<!DOCTYPE html>
<html lang="zh-CN">
<?php md_head($title) ?>
<body>
<?php

$mode = safe_get($_GET, 'm');
if ($mode == 'embed') {
    md_sub_frame($page, $file);

} else {
    md_main_frame($page, $file, $title, $nav);

}
?>
</body>
</html>
<?php

}

