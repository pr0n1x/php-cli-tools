#!/usr/bin/env php
<?php

$options = getopt('e:d:');
if(!empty($options['e'])) {
	die(idn_to_ascii(trim($options['e'])).PHP_EOL);
}
if(!empty($options['d'])) {
	die(idn_to_utf8(trim($options['d'])).PHP_EOL);
}
