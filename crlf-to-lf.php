#!/usr/bin/env php
<?php
/**
 * @global array $argv
 * @global int $argc
 */
namespace Devtop\Tools;

if(!isset($argv) || !isset($argc)) {
	echo 'This script must be executed from CLI.';
}
/** @noinspection PhpUndefinedVariableInspection */
CrlfConverter::main($argc, $argv);

class CrlfConverter {

	static private $fileExtAllowDefault = [
		'php',
		'html',
		'css',
		'less',
		'sass',
		'xml',
		'json',
		'log',
		'htaccess',
		'gitignore',
		'tpl',
		'tmpl',
		'sql'
	];

	static private $argc = 0;
	static private $argv = [];
	static private $curDir = null;
	static private $optsConversionTypes = null;

	const CONV_TYPE_CRLF_TO_LF = 'crlf2lf';
	const CONV_TYPE_CRLF_TO_CR = 'crlf2cr'; // устаревший вариант для mac os <= 9
	const CONV_TYPE_LF_TO_CRLF = 'lf2crlf';
	const CONV_TYPE_LF_TO_CR   = 'lf2cr'; // Устареший вариант для mac os <= 9
	const CONV_TYPE_CR_TO_LF   = 'cr2lf'; // устаревший вариант для mac os <= 9
	const CONV_TYPE_CR_TO_CRLF = 'cr2crlf'; // устаревший вариант для mac os <= 9


	static public function main($argc, $argv) {
		self::$argc = $argc;
		self::$argv = $argv;

		self::$optsConversionTypes = [
			self::CONV_TYPE_CRLF_TO_LF => self::CONV_TYPE_CRLF_TO_LF,
			self::CONV_TYPE_CRLF_TO_CR => self::CONV_TYPE_CRLF_TO_CR,
			self::CONV_TYPE_LF_TO_CRLF => self::CONV_TYPE_LF_TO_CRLF,
			self::CONV_TYPE_LF_TO_CR   => self::CONV_TYPE_LF_TO_CR,
			self::CONV_TYPE_CR_TO_LF   => self::CONV_TYPE_CR_TO_LF,
			self::CONV_TYPE_CR_TO_CRLF => self::CONV_TYPE_CR_TO_CRLF,

			'win2nix' => self::CONV_TYPE_CRLF_TO_LF,
			'win2macx' => self::CONV_TYPE_CRLF_TO_LF,
			'nix2win' => self::CONV_TYPE_LF_TO_CRLF,
			'macx2win' => self::CONV_TYPE_LF_TO_CRLF,

			'maci2win' => self::CONV_TYPE_CR_TO_CRLF,
			'maci2nix' => self::CONV_TYPE_CR_TO_LF,
			'win2maci' => self::CONV_TYPE_CRLF_TO_CR,
			'nix2maci' => self::CONV_TYPE_LF_TO_CR
		];

		if( self::$argc < 1 || empty(self::$argv[1]) ) {
			self::showUsage();
			exit(0);
		}

		self::$curDir = getcwd();

		$opts = getopt('ht::a::d::e::', array(
			'type::',
			'allow-ext::',
			'deny-ext::',
			'exclude::',
			'help'
		));

		if( isset($opts['h']) || isset($opts['help']) ) {
			self::showUsage();
			exit(0);
		}

		$conversionType = null;
		if( isset($opts['t']) ) {
			$conversionType = $opts['t'];
		}
		elseif( isset($opts['type']) ) {
			$conversionType = $opts['type'];
		}
		if( null === self::checkConversionType($conversionType) ) {
			echo PHP_EOL.'Error: Wrong conversion type'.PHP_EOL;
			self::showUsage();
			exit(0);
		}

		$workFiles = [];
		$fileExtAllow = null;
		//$fileExtDeny = [];
		$excludePathList = [];
		$fileExtAllowOptsString = '';
		$excludeOptsString = '';

		if( !empty($opts['a']) ) {
			if( is_array($opts['a']) )
				$fileExtAllowOptsString .= ','.implode(',', $opts['a']);
			else
				$fileExtAllowOptsString .= ','.$opts['a'];
		}
		if( !empty($opts['allow-ext']) ) {
			if( is_array($opts['allow-ext']) )
				$fileExtAllowOptsString .= ','.implode(',', $opts['allow-ext']);
			else
				$fileExtAllowOptsString .= ','.$opts['allow-ext'];
		}
		$fileExtAllowOptsString = trim($fileExtAllowOptsString, ', ');

		if( !empty($fileExtAllowOptsString) ) {
			$fileExtAllow = explode(',', $fileExtAllowOptsString);
		}
		if( empty($fileExtAllow) ) {
			/** @noinspection PhpUnusedLocalVariableInspection */
			$fileExtAllow = self::$fileExtAllowDefault;
		}

		if( !empty($opts['e']) ) {
			if( is_array($opts['e']) )
				$excludeOptsString .= PATH_SEPARATOR.implode(PATH_SEPARATOR, $opts['e']);
			else
				$excludeOptsString .= PATH_SEPARATOR.$opts['e'];
		}
		if( !empty($opts['exclude']) ) {
			if( is_array($opts['exclude']) )
				$excludeOptsString .= PATH_SEPARATOR.implode(PATH_SEPARATOR, $opts['exclude']);
			else
				$excludeOptsString .= PATH_SEPARATOR.$opts['exclude'];
		}
		$excludeOptsString = trim($excludeOptsString, PATH_SEPARATOR.' ');
		if( !empty($excludeOptsString) ) {
			$excludePathList = explode(PATH_SEPARATOR, $excludeOptsString);
			foreach($excludePathList as &$excludePath)
				$excludePath = trim($excludePath, DIRECTORY_SEPARATOR.' ');
		}

		foreach($argv as $argNum => $argValue) {
			if($argNum == 0 || substr($argValue, 0 ,1) == '-') continue;
			foreach(glob($argValue, GLOB_BRACE) as $path) {
				self::handlePath($path, function($path) use (&$workFiles, &$fileExtAllow, &$excludePathList) {
					$fileExt = substr($path, strrpos($path, '.')+1);
					if( !in_array($fileExt, $fileExtAllow) ) return true;
					if( in_array($path, $workFiles) ) return true;
					$bExcluded = false;
					foreach($excludePathList as &$excludePath) {
						$excludePath = trim($excludePath, DIRECTORY_SEPARATOR.' ');
						if( strpos($path, $excludePath.DIRECTORY_SEPARATOR) === 0 ) {
							$bExcluded = true;
							break;
						}
					}
					if( true === $bExcluded ) return true;
					//echo 'path: '.$path.PHP_EOL;
					$workFiles[] = $path;
					return true;
				});
			}
		}

		if( empty($workFiles) ) {
			self::showUsage();
			exit(0);
		}

		foreach($workFiles as $filePath) {
			self::convert($filePath, $conversionType);
		}
	}


	static private function checkConversionType($type) {
		if( array_key_exists($type, self::$optsConversionTypes) ) {
			$type = self::$optsConversionTypes[$type];
		}
		switch( $type ) {
			case self::CONV_TYPE_CRLF_TO_LF:
				return ["\r\n", "\n"];
			case self::CONV_TYPE_LF_TO_CRLF:
				return ["\n", "\r\n"];
			// old not usable variants with CR. CR used long time ago in mac os older then version 10
			case self::CONV_TYPE_LF_TO_CR:
				return ["\n", "\r"];
			case self::CONV_TYPE_CR_TO_LF:
				return ["\r", "\n"];
			case self::CONV_TYPE_CR_TO_CRLF:
				return ["\r", "\r\n"];
			case self::CONV_TYPE_CRLF_TO_CR:
				return ["\r\n", "\r"];
		}
		return null;
	}

	static private function convert(&$filePath, $conversionType) {
		$convert = self::checkConversionType($conversionType);
		if(!empty($convert)) {
			echo $filePath.': '
				.str_replace(["\r", "\n"], ["\\r", "\\n"], $convert[0])
				.' -> '
				.str_replace(["\r", "\n"], ["\\r", "\\n"], $convert[1])
				.PHP_EOL;
			$fileContent = file_get_contents(self::$curDir.'/'.$filePath);
			$fileContent = str_replace(["\r\n", $convert[0]], "\n", $fileContent);
			$fileContent = str_replace("\n", $convert[1], $fileContent);
			file_put_contents($filePath, $fileContent);
		}
	}

	function handlePath($path, $handler) {
		if(strlen($path) == 0 || $path == '/') return false;
		if( !is_callable($handler) ) return false;
		$result = true;
		if( substr($path, 0, 2) == '.'.DIRECTORY_SEPARATOR ) {
			$path = trim(substr($path, 2), DIRECTORY_SEPARATOR);
		}
		if( is_file($path) || is_link($path) ) {
			return !!call_user_func_array($handler, [$path]);
		}
		elseif( is_dir($path) ) {
			if( $d = opendir($path) ) {
				while(($file = readdir($d)) !== false) {
					if($file == '.' || $file == '..') continue;
					if(!self::handlePath($path.'/'.$file, $handler)) {
						$result = false;
					}
				}
				closedir($d);
				return $result;
			}
			else return false;
		}
		return false;
	}

	function showUsage() {
		$defaultExtListString = implode(',', self::$fileExtAllowDefault);
		//global $argv;
		$argv = self::$argv;
		echo <<<USAGE

Usage: {$argv[0]} <OPTIONS> <file path pattern 1> [<pattern 2> [<pattern 3>]]

    OPTIONS:
    -h | --help - Show usage
    -t=<conversion type> | --type=<conversion type>
        crlf2lf | win2nix | win2macx - Windows to Unix (includes Mac OS X)
        lf2crlf | nix2win | macx2win - Unix (includes Mac OS X) to Windows
        # Old Macinosh
        lf2cr | nix2maci - Unix to Macintosh
        cr2lf | maci2nix - Macintosh to Unix
        cr2crlf | maci2win - Macintosh to Windows
        crlf2cr | win2maci - Windows to Macintosh
    -a=<ext list> | --allow-ext=<ext list>
        Set extensions list for conversion
        <ext list> example: --allow-ext=php,js,css
        by default: -a={$defaultExtListString}
    -d=<ext list> | --deny-ext=<ext list>
        !Not implemented yet! Set extensions list denied for conversion
    -e | --exclude - Excludes defined file path pattern from conversion
        Example: {$argv[0]} -e=bitrix/templates/site_template/components/salerman bitrix/templates/site_template


USAGE;
	}
}


/**
 * @product OBX:Core Bitrix Module
 * @author Maksim S. Makarov aka pr0n1x
 * @license Affero GPLv3
 * @mailto rootfavell@gmail.com
 * @copyright 2013 Devtop
 */
class Mime {

	const GRP_UNKNOWN = null;
	const GRP_TEXT = 'text';
	const GRP_IMAGE = 'image';
	const GRP_ARCH = 'archive';
	const GRP_DOC = 'document';
	const GRP_AUDIO = 'audio';
	const GRP_VIDEO = 'video';
	const GRP_OTHER = 'other';

	private static $arInstances = array();

	protected $arMimeExt = null;
	protected $arMimeGroups = null;
	protected $arMimeText = array(
		'application/json' => 'json',
		'text/html' => 'html',
		'text/plain' => 'txt',
		'application/xml' => 'xml',
		'text/xml' => 'xml',
	);

	protected $arMimeImages = array(
		'image/png' => 'png',
		'image/jpeg' => 'jpg',
		'image/gif' => 'gif',
		'image/x-icon' => 'ico',
		'image/x-tiff' => 'tiff',
		'image/tiff' => 'tiff',
		'image/svg+xml' => 'svg',
		'application/pcx' => 'pcx',
		'image/x-bmp' => 'bmp',
		'image/x-MS-bmp' => 'bmp',
		'image/x-ms-bmp' => 'bmp',
	);

	protected $arMimeCompressedTypes = array(
		'application/x-rar-compressed' => 'rar',
		'application/x-rar' => 'rar',
		'application/x-tar' => 'tar',
		'application/x-bzip2' => 'bz2',
		'application/x-bzip-compressed-tar' => 'tar.bz2',
		'application/x-bzip2-compressed-tar' => 'tar.bz2',
		'application/zip' => 'zip',
		'application/x-7z-compressed' => '7z',
		'application/x-gzip' => 'gz',
		'application/x-gzip-compressed-tar' => 'tar.gz',
		'application/x-xz' => 'xz',
		'application/x-iso9660-image' => 'iso'
	);



	protected $arMimeDocuments = array(
		//doc
		//open docs
		'application/vnd.oasis.opendocument.text' => 'odt',
		'application/vnd.oasis.opendocument.spreadsheet' => 'pds',
		'application/vnd.oasis.opendocument.presentation' => 'odp',
		'application/vnd.oasis.opendocument.graphics' => 'odg',
		'application/vnd.oasis.opendocument.chart' => 'odc',
		'application/vnd.oasis.opendocument.formula' => 'odf',
		'application/vnd.oasis.opendocument.image' => 'odi',
		'application/vnd.oasis.opendocument.text-master' => 'odm',
		'application/vnd.oasis.opendocument.text-template' => 'ott',
		'application/vnd.oasis.opendocument.spreadsheet-template' => 'ots',
		'application/vnd.oasis.opendocument.presentation-template' => 'otp',
		'application/vnd.oasis.opendocument.graphics-template' => 'otg',
		'application/vnd.oasis.opendocument.chart-template' => 'otc',
		'application/vnd.oasis.opendocument.formula-template' => 'otf',
		'application/vnd.oasis.opendocument.image-template' => 'oti',
		'application/vnd.oasis.opendocument.text-web' => 'oth',
		//prop docs
		'application/rtf' => 'rtf',
		'application/pdf' => 'pdf',
		'application/postscript' => 'ps',
		'application/x-dvi' => 'dvi',
		'application/msword' => 'doc',
		'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 'docx',
		'application/vnd.ms-powerpoint' => 'ppt',
		'application/vnd.openxmlformats-officedocument.presentationml.presentation' => 'pptx',
		'application/vnd.ms-excel' => 'xls',
		'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => 'xlsx',
	);

	protected $arMimeAudio = array(
		'audio/midi' => 'midi',
		'audio/x-midi' => 'midi',
		'audio/mod' => 'mod',
		'audio/x-mod' => 'mod',
		'audio/mpeg3' => 'mp3',
		'audio/x-mpeg3' => 'mp3',
		'audio/mpeg-url' => 'mp3',
		'audio/x-mpeg-url' => 'mp3',
		'audio/mpeg2' => 'mp2',
		'audio/x-mpeg2' => 'mp2',
		'audio/mpeg' => 'mpa',
		'audio/x-mpeg' => 'mpa',
		'audio/wav' => 'wav',
		'audio/x-wav' => 'wav',
		'audio/flac' => 'flac',
		'audio/x-ogg' => 'ogg'
	);

	protected $arMimeVideo = array(
		'video/mpeg' => 'mpg',
		'video/x-mpeg' => 'mpg',
		'video/sgi-movie' => 'movi',
		'video/x-sgi-movie' => 'movi',
		'video/msvideo' => 'avi',
		'video/x-msvideo' => 'avi',
		'video/fli' => 'fli',
		'video/x-fli' => 'fli',
		'video/quicktime' => 'mov',
		'video/x-quicktime' => 'mov',
		'application/x-shockwave-flash' => 'swf',
		'video/x-ms-wmv' => 'wmv',
		'video/x-ms-asf' => 'asf',
	);


	protected function __construct() {
		if( null === $this->arMimeExt ) {
			$this->arMimeExt = array_merge(
				$this->arMimeText,
				$this->arMimeImages,
				$this->arMimeCompressedTypes,
				$this->arMimeDocuments,
				$this->arMimeAudio,
				$this->arMimeVideo
			);
		}
		if( null === $this->arMimeGroups ) {
			$this->arMimeGroups = array();
			foreach($this->arMimeText as $type => $ext) {
				$this->arMimeGroups[$type] = static::GRP_TEXT;
			}
			foreach($this->arMimeImages as $type => $ext) {
				$this->arMimeGroups[$type] = static::GRP_IMAGE;
			}
			foreach($this->arMimeCompressedTypes as $type => $ext) {
				$this->arMimeGroups[$type] = static::GRP_ARCH;
			}
			foreach($this->arMimeDocuments as $type => $ext) {
				$this->arMimeGroups[$type] = static::GRP_DOC;
			}
			foreach($this->arMimeAudio as $type => $ext) {
				$this->arMimeGroups[$type] = static::GRP_AUDIO;
			}
			foreach($this->arMimeVideo as $type => $ext) {
				$this->arMimeGroups[$type] = static::GRP_VIDEO;
			}
		}
	}

	/**
	 * @return self
	 */
	final public static function getInstance() {
		$class = get_called_class();
		if( !array_key_exists($class, self::$arInstances)
			|| !(self::$arInstances[$class] instanceof self)
		) {
			self::$arInstances[$class] = new $class;
		}
		return self::$arInstances[$class];
	}

	public function & _refMimeData() {
		return $this->arMimeExt;
	}

	public function getMimeData() {
		return $this->arMimeExt;
	}

	/**
	 * @param string $type
	 * @param string $fileExt
	 * @param int|null $group
	 * @return bool
	 */
	public function addType($type, $fileExt, $group = null) {
		if( array_key_exists($type, $this->arMimeExt) ) {
			return false;
		}
		$this->arMimeExt[$type] = $fileExt;
		if(null !== $group) {
			switch($group) {
				case static::GRP_TEXT:
				case static::GRP_IMAGE:
				case static::GRP_ARCH:
				case static::GRP_DOC:
				case static::GRP_AUDIO:
				case static::GRP_VIDEO:
					$this->arMimeGroups[$type] = $group;
			}
		}
		return true;
	}

	/**
	 * @param string $mimeType
	 * @param null|string $defaultExt
	 * @return null|string
	 */
	public function getFileExt($mimeType, $defaultExt = null) {
		if(array_key_exists($mimeType, $this->arMimeExt)) {
			return $this->arMimeExt[$mimeType];
		}
		return $defaultExt;
	}

	public function getContentGroup($mimeType) {
		if(array_key_exists($mimeType, $this->arMimeGroups)) {
			return $this->arMimeGroups[$mimeType];
		}
		return static::GRP_UNKNOWN;
	}
}
