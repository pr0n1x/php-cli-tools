#!/usr/bin/env php
<?php

if(!isset($argv) || !isset($argc)) {
	echo 'This script must be executed from CLI.';
}

$curDir = realpath(dirname($argv[0]));
$gitStatus = `git status | awk '{print $1":"$2}'`;
$gitStatusLines = explode(PHP_EOL, $gitStatus);
echo PHP_EOL;
foreach($gitStatusLines as $statusLine) {
	if( 0 === strpos($statusLine, 'изменено::') ) {
		list($statusLinePrefix, $filePath) = explode('::', $statusLine);
		echo $filePath.PHP_EOL;
		$fileContent = file_get_contents($curDir.'/'.$filePath);
		$fileContent = str_replace("\r\n", "\n", $fileContent);
		file_put_contents($curDir.'/'.$filePath, $fileContent);
	}
}