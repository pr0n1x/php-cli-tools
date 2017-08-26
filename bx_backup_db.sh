#!/bin/bash

# config
documentRoot="${HOME}/www/domain.ru";
backupFolder="${HOME}/backup"
backupName="domain.ru"


# vars
currentTime=`date +%Y-%m-%d-%H%M`;
backupFileName="${backupName}.db-${currentTime}.sql"
backupFilePath="$backupFolder/$backupFileName"
dbUser=`cat $documentRoot/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep '\$DB' | grep '\$DBLogin' | awk -F '=' '{print $2}' | awk -F '"' '{print $2}'`;
dbPass=`cat $documentRoot/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep '\$DB' | grep '\$DBPassword' | awk -F '=' '{print $2}' | awk -F '"' '{print $2}'`;
dbName=`cat $documentRoot/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep '\$DB' | grep '\$DBName' | awk -F '=' '{print $2}' | awk -F '"' '{print $2}'`;
dbUseUtf8=`cat $documentRoot/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep 'define(' | grep 'BX_UTF' | awk -F ',' '{print $2}' | awk -F ')' '{print $1}' | sed -e 's/[[:space:]]*//'`;
dbDefaultCharset=cp1251
if [ "_true_" = "_${dbUseUtf8}_" ]; then
	dbDefaultCharset=utf8
fi

# logic :)
show_help() {
	echo "Usage: [-h|-f|-p|...]"
	echo "    -h | --help       - Show this help message"
	echo "    -p | --pipe       - Not create file and put data to stdout"
	echo "    -f | --file       - Create backup file"
	echo "    -z | --gzip       - Use gzip compression"
	echo "    --show-db-name    - mmm.. this option show database name..."
	echo "    --show-db-user    - mmm.. you know"
	echo "    --show-db-pass    - Ah! Don't use this option in public places!"
	echo "    --show-db-charset - Ok. This option you can use any where."
}
OPTS=`getopt -o hpfz --long 'help,show-db-name,show-db-user,show-db-pass,show-db-charset,pipe,file,gzip,zip' -n 'parse-options' -- $@`
#echo $OPTS;
if [ $? != 0 ] ; then show_help >&2 ; exit 1 ; fi
eval set -- $OPTS;

use_pipe="N"
use_gzip="N"
stdout_printed="N"
do_operation="N"
while (( $# )); do
	#echo "Opts: $@";
	case $1 in
		-h | --help)
			show_help;
			shift;
			break;
		;;
		--show-db-name)
			echo "Database name: $dbName";
			stdout_printed="Y";
			shift;
		;;
		--show-db-user)
			echo "Database user: $dbUser";
			stdout_printed="Y";
			shift;
		;;
		--show-db-pass)
			echo "Database password: $dbPass";
			stdout_printed="Y";
			shift;
		;;
		--show-db-charset)
			echo "Database charset: $dbDefaultCharset";
			stdout_printed="Y";
			shift;
		;;
		-z | --gzip | --zip)
			use_gzip="Y";
			shift;
		;;
		-f | --file)
			do_operation="Y";
			use_pipe="N";
			shift;
		;;
		-p | --pipe)
			do_operation="Y";
			use_pipe="Y";
			shift;
		;;
		--)
			if [ "xY" = "x$do_operation" ]; then
				if [ "xY" = "x$use_pipe" ]; then
					if [ "xY" = "x$stdout_printed" ]; then
						echo "You can't use pipe option with one of the --show-* options" 1>&2;
						false;
					else
						if [ "xY" = "x$use_gzip" ]; then
							mysqldump -u$dbUser -p$dbPass $dbName --default-character-set=$dbDefaultCharset | gzip
						else
							mysqldump -u$dbUser -p$dbPass $dbName --default-character-set=$dbDefaultCharset
						fi
					fi
				else
					if [ "xY" = "x$use_gzip" ]; then
						mysqldump -u$dbUser -p$dbPass $dbName --default-character-set=$dbDefaultCharset > $backupFilePath && gzip $backupFilePath
					else
						mysqldump -u$dbUser -p$dbPass $dbName --default-character-set=$dbDefaultCharset > $backupFilePath
					fi
				fi
			fi
			exit $?;
		;;
		*) shift; ;;
	esac
done

