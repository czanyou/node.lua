<?php

date_default_timezone_set('PRC');


// 实现一个简单的文件浏览器

function dir_path($path) { 
	if (!$path || $path == '') {
		return '';
	}

	$path = str_replace('\\', '/', $path); 
	if (substr($path, -1) != '/') {
		$path = $path . '/'; 
	}
	return $path; 
} 

/** 
* 列出目录下的所有文件 
* 
* @param str $path 目录 
* @param str $exts 后缀 
* @param array $list 路径数组 
* @return array 返回路径数组 
*/ 
function dir_list($path, $exts = '', $list = array()) { 
	$path = dir_path($path);
	$files = glob($path . '*');

	foreach ($files as $v) { 
		if (preg_match("/\.(php)/i", $v)) {
			continue;
		}

		if (!$exts || preg_match("/\.($exts)/i", $v)) { 
			$file = array();
			$file['is_dir'] = is_dir($v);
			$file['name'] = $v;

			$list[] = $file;
		} 
	}
	return $list; 
}

function dir_name($dirname) {
	$len = strlen($dirname);
	if ($len >= 24) {
		return $dirname . "</a>\t";

	} else if ($len >= 16) {
		return $dirname . "</a>\t\t";

	} else if ($len >= 8) {
		return $dirname . "</a>\t\t\t";

	} else {
		return $dirname . "</a>\t\t\t\t";		
	}
}

function dir_show($file) {
	$filename = basename($file['name']);
	$fileurl  = $file['url'];
	$handle   = fopen($file['name'],"r");
	$fstat    = fstat($handle);
	$filesize = $fstat["size"];
	$filetime = date("Y-m-d h:i:s", $fstat["mtime"]);

	if (!isset($file['is_dir'])) {
		$filename = dir_name($filename . '/');
		printf("<a href=\"?dir=%s\">%s\r\n", $fileurl, $filename);

	} else if ($file['is_dir']) {
		$filename = dir_name(dir_path($filename));
		$fileurl = dir_path($fileurl);
		printf("<a href=\"?dir=%s\">%s\t%s\t%s\r\n", $fileurl, $filename, $filetime, '-');

	} else {
		$filename = dir_name($filename);
		printf("<a href=\"%s\">%s\t%s\t%s\r\n", $fileurl, $filename, $filetime, $filesize);
	}
}

function dir_join($basePath, $filename) {
	if ($basePath && strlen($basePath) > 0) {
		return $basePath . '' . $filename;
	} else {
		return $filename;
	}
}

function dir_print_list($rootPath) {
	$dirPath  = $rootPath;
	$basePath = '';

	if (isset($_GET['dir'])) {
		$basePath = dir_path($_GET['dir']);
		$dirPath  = $rootPath . '/' . $basePath;
	}

	printf("<html><head><title>Index of /%s</title>", $basePath);
	printf("</head><body>");
	printf("<h1>Index of /%s</h1>", $basePath);
	printf("<hr/>");
	printf('<pre style="line-height: 160%%;">');


	if ($basePath && strlen($basePath) > 0) {
		$fileurl = substr(dirname('/' . $basePath), 1);
		dir_show(array("name"=>"..", "url"=>$fileurl));
	}

	$files = dir_list($dirPath); 
	foreach ($files as $file) {
		$file['url'] = dir_join($basePath, basename($file['name']));
		if ($file['is_dir']) { dir_show($file); }
	}

	foreach ($files as $file) {
		$file['url'] = dir_join($basePath, basename($file['name']));
		if (!$file['is_dir']) { dir_show($file); }
	}

	printf("</pre>");
	printf("<hr/>");


}

define('S_ROOT', dirname(__FILE__));    ///< System Root Path
dir_print_list(S_ROOT);

printf('<a href="upload.php">Upload Files</a>');

