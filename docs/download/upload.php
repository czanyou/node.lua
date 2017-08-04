<?php

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

if (isset($_FILES["file"])) {
    $file     = $_FILES["file"];

    $fileType = $file["type"];
    $fileSize = $file["size"];
    $fileName = $file["name"];

    $basePath = 'cache/';
    if (isset($_GET['dist'])) {
      $basePath = dir_path($_GET['dist']);
    }

    echo "{\r\n";

    if ($file["error"] > 0) {
        echo '"error": ' . $file["error"] . ",\r\n";

    } else {
        echo '"temp": "'  . $file["tmp_name"] . '",' . "\r\n";

        mkdir($basePath, 0777, true);
        chmod($basePath, 0777);

        $ret = move_uploaded_file($file["tmp_name"], $basePath . $fileName);
        echo '"ret": '  . ($ret ? '0' : '-1') . ',' . "\r\n";
    }

    echo '"name": "'  . $fileName . '",' . "\r\n";
    echo '"type": "'  . $fileType . '",' . "\r\n";
    echo '"size": '   . $fileSize . "\r\n";
    echo "}\r\n";

    return;
}

?>
<html>
<head>
  <style>
  body { font-size: 16px; }
  form ul { padding: 64px 16px;  }
  form ul dt { padding: 8px 16px;  }
  form .label { font-size: 16px; }
  form .file { padding: 8px 16px; background-color: #eee; font-size: 16px; }
  form .button { padding: 8px 16px; font-size: 16px; }
  </style>
</head>
<body>
  <form action="upload.php" method="post" enctype="multipart/form-data"><ul>

    <dt><label class="label" for="file">Select File:</label></dt>
    <dt><input class="file" type="file" name="file" id="file" /></dt>

    <dt><input class="button" type="submit" name="submit" value="Submit" /></dt>
  </ul></form>
</body>
</html>
