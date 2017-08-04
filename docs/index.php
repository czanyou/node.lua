<?php

require_once('assets/common.php');

$title = "Node.lua - 开放平台";
$nav = array(
    array('dev',    'home', '开发'),
    array('docs',   'home', '文档'),
    array('api',    'home', 'API'),
    array('vision', 'home', '扩展'),
    array('cloud',  'home', '云服务')
);

md_print_docs('docs', 'home.md', $title, $nav);
