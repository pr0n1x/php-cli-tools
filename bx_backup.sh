#!/bin/bash
#
# if script named "bx_backup.domain.ru.sh"
# then config file must me named as "bx_backup.domain.ru.conf"
# config file example:
#
#  documentRoot="${HOME}/www/domain.ru";
#  backupFolder="${HOME}/backup"
#  backupName="domain.ru"
#

self_dir=$(cd $(dirname $0); pwd;);
self_name=`basename $0`;
self_name=${self_name%.*};

CWD=`pwd`;

if [ ! -f ${self_dir}/${self_name}.conf ]; then
	echo "Config file ${self_name}.conf not found";
	exit 1;
fi

source ${self_dir}/${self_name}.conf;

if [ ! -d $documentRoot ]; then
	echo "Document root not found in config file";
	exit 1;
fi
if [ ! -d $backupFolder ]; then
	echo "Backup folder not found in config file";
	exit 1;
fi
backupName=`echo $backupName | sed 's/\ \	//g'`;
if [ "x" = "x$backupName" ]; then
	echo "Backup name does not set";
	exit 1;
fi


currentTime=`date +%Y-%m-%d-%H%M`;
backupFileName="${backupName}.bak-${currentTime}"
backupFilePath="$backupFolder/$backupFileName"
dbUser=`cat $documentRoot/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep '\$DB' | grep '\$DBLogin' | awk -F '=' '{print $2}' | awk -F '"' '{print $2}'`;
dbPass=`cat $documentRoot/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep '\$DB' | grep '\$DBPassword' | awk -F '=' '{print $2}' | awk -F '"' '{print $2}'`;
dbName=`cat $documentRoot/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep '\$DB' | grep '\$DBName' | awk -F '=' '{print $2}' | awk -F '"' '{print $2}'`;
dbUseUtf8=`cat $documentRoot/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep 'define(' | grep 'BX_UTF' | awk -F ',' '{print $2}' | awk -F ')' '{print $1}' | sed -e 's/[[:space:]]*//'`;
dbDefaultCharset=cp1251
if [ "_true_" = "_${dbUseUtf8}_" ]; then
	dbDefaultCharset=utf8
fi

show_help() {
	echo "Usage: [-h|-f|-p|...]"
	echo "    -h | --help        - Show this help message"
	echo "    -p | --pipe        - Do not create file and push data to stdout"
	echo "    -f | --files       - Create backup of the bitrix program files"
	echo "    -u | --upload      - Create backup of the bitrix upload folder"
	echo "    -a | --all-files   - Create full backup except database dump file :)"
	echo "    -w | --whole       - Not implemented yet. Create whole files to backup with database"
	echo "    -d | --db          - Backup database"
	echo "    -z | --gzip        - Use gzip compression"
	echo "    -j | --bzip        - Use bzip2 compression"
	echo "    -v | --tar-verbose - Show tar report (tar option -v)"
	echo "    --tar-perm         - Save files permisions (tar option -p)"
	echo "    --show-db-name     - mmm.. this option shows database name..."
	echo "    --show-db-user     - mmm.. you know"
	echo "    --show-db-pass     - Ah! Don't use this option in public places!"
	echo "    --show-db-charset  - Ok. This option you can use any where."
}
OPTS=`getopt -o hpfuadwzjv --long 'help,pipe,files,upload,all,db,whole,gzip,zip,bzip2,bzip,tar-verbose,tar-perm,show-db-name,show-db-user,show-db-pass,show-db-charset' -n 'parse-options' -- $@`
#echo $OPTS;
if [ $? != 0 ] ; then show_help >&2 ; exit 1 ; fi
eval set -- $OPTS;
if [ "x--" = "x$1" ]; then
	show_help 1>&2;
	exit 1;
fi

use_pipe="N";
use_gzip="N";
use_bzip="N";
stdout_printed="N";
make_files="N" # make bitrix program files
make_upload="N"; # make bitrix upload files
make_db="N"; # make bitrix database backup
make_whole="N"; # backup all files and database sql-backup file inside. Not implemented yet.
tar_save_perm="N";
tar_verbose="N";
show_db_name="N";
show_db_user="N";
show_db_pass="N";
while (( $# )); do
	#echo "Opts: $@";
	case $1 in
		-h | --help)
			show_help;
			shift;
			break;
		;;
		--show-db-name)
			show_db_name="Y";
			shift;
		;;
		--show-db-user)
			show_db_user="Y";
			shift;
		;;
		--show-db-pass)
			show_db_pass="Y";
			shift;
		;;
		--show-db-charset)
			echo "Database charset: $dbDefaultCharset";
			shift;
		;;
		-z | --gzip | --zip)
			use_gzip="Y";
			shift;
		;;
		-j | --bzip2 | --bzip)
			use_bzip="Y";
			shift;
		;;
		-v | --tar-verbose)
			tar_verbose="Y";
			shift;
		;;
		--tar-perm)
			tar_save_perm="Y";
			shift;
		;;
		-f | --files)
			make_files="Y";
			shift;
		;;
		-u | --upload)
			make_upload="Y";
			shift;
		;;
		-d | --db | --database)
			make_db="Y";
			shift;
		;;
		-a | --all)
			make_db="Y";
			make_files="Y";
			shift;
		;;
		-w | --whole)
			echo "Whole backup not implemented yet.";
			exit 1;
		;;
		-p | --pipe)
			use_pipe="Y";
			shift;
		;;
		--)
			return_status=0;
			notPipeFileAndDb="Error: You can't make backup of files and database and use pushing to pipe at the same time";
			if [ "xY" = "x$use_pipe" ] && [ "xY" = "x$make_db" ] && [ "xY" = "x$make_files" ]; then
				echo $notPipeFileAndDb 1>&2;
				exit 1;
			elif [ "xY" = "x$use_pipe" ] && [ "xY" = "x$make_db" ] && [ "xY" = "x$make_upload" ]; then
				echo $notPipeFileAndDb 1>&2;
				exit 1;
			elif [ "xN" = "x$make_db" ] && [ "xN" = "x$make_files" ] && [ "xN" = "x$make_upload" ]; then
				echo "Error: Backup type is not selected. Use options: -f|-u|-a|-d" 1>&2;
				show_help 1>&2;
				exit 1;
			elif [ "xY" = "x$use_gzip" ] && [ "xY" = "x$use_bzip" ]; then
				echo "Error: You should to choose one of the compression methods: gzip or bzip2, but not both at the same time" 1>&2;
				show_help 1>&2;
				exit 1;
			else
				#show db connection params
				if [ "xY" = "x$show_db_name" ]; then
					if [ "xY" = "x$use_pipe" ]; then
						echo "Database name: $dbName" 1>&2;
					else
						echo "Database name: $dbName";
					fi
				fi
				if [ "xY" = "x$show_db_user" ]; then
					if [ "xY" = "x$use_pipe" ]; then
						echo "Database user: $dbUser" 1>&2;
					else
						echo "Database user: $dbUser";
					fi
				fi
				if [ "xY" = "x$show_db_pass" ]; then
					if [ "xY" = "x$use_pipe" ]; then
						echo "Database password: $dbPass" 1>&2;
					else
						echo "Database password: $dbPass";
					fi
				fi
			
				#make database backup
				compression_message="";
				tar_file_ext="";
				if [ "xY" = "x$use_gzip" ]; then
					compression_message="(gzip compression)";
					tar_file_ext="tar.gz";
				elif [ "xY" = "x$use_bzip" ]; then
					compression_message="(bzip2 compression)";
					tar_file_ext="tar.bz2";
				else
					compression_message="(w/o compression)";
					tar_file_ext="tar";
				fi
				if [ "xY" = "x$make_db" ]; then
					if [ "xY" = "x$use_pipe" ]; then
						printf "Making database backup $compression_message..." 1>&2;
						if [ "xY" = "x$use_gzip" ]; then
							mysqldump -u$dbUser -p$dbPass $dbName --default-character-set=$dbDefaultCharset | gzip
						elif [ "xY" = "x$use_bzip" ]; then
							mysqldump -u$dbUser -p$dbPass $dbName --default-character-set=$dbDefaultCharset | bzip2
						else
							mysqldump -u$dbUser -p$dbPass $dbName --default-character-set=$dbDefaultCharset
						fi
						return_status=$?;
						if [ "x0" = "x$return_status" ]; then echo "OK" 1>&2; fi
					else
						printf "Making database backup $compression_message...";
						if [ "xY" = "x$use_gzip" ]; then
							mysqldump -u$dbUser -p$dbPass $dbName --default-character-set=$dbDefaultCharset > ${backupFilePath}.db.sql && gzip ${backupFilePath}.db.sql;
						elif [ "xY" = "x$use_bzip" ]; then
							mysqldump -u$dbUser -p$dbPass $dbName --default-character-set=$dbDefaultCharset > ${backupFilePath}.db.sql && bzip2 ${backupFilePath}.db.sql;
						else
							mysqldump -u$dbUser -p$dbPass $dbName --default-character-set=$dbDefaultCharset > ${backupFilePath}.db.sql;
						fi
						return_status=$?;
						if [ "x0" = "x$return_status" ]; then echo "OK"; fi
					fi
				fi
				
				#make files backup
				tarExcludes="";
				tarExcludes="$tarExcludes --exclude=./bitrix/cache";
				tarExcludes="$tarExcludes --exclude=./bitrix/managed_cache";
				tarExcludes="$tarExcludes --exclude=./bitrix/stack_cache";
				tarExcludes="$tarExcludes --exclude=./bitrix/backup";
				tarExcludes="$tarExcludes --exclude=./bitrix/tmp";
				tarExcludes="$tarExcludes --exclude=./local/tmp";
				tarExcludes="$tarExcludes --exclude=./.idea";
				tarExcludes="$tarExcludes --exclude=./.git";
				tarExcludes="$tarExcludes --exclude=./*.tar";
				tarExcludes="$tarExcludes --exclude=./*.gz";
				tarExcludes="$tarExcludes --exclude=./*.bz";
				tarExcludes="$tarExcludes --exclude=./*.bz2";
				tarExcludes="$tarExcludes --exclude=./*.zip";
				tarExcludes="$tarExcludes --exclude=./*.rar";
				tarExcludes="$tarExcludes --exclude=./*.7z";
				tarExcludes="$tarExcludes --exclude=./*.lzma";
				tarOpts="c";
				if [ "xY" = "x$tar_verbose" ]; then
					tarOpts="${tarOpts}v";
				fi
				if [ "xY" = "x$use_gzip" ]; then
					tarOpts="${tarOpts}z";
				fi
				if [ "xY" = "x$use_bzip" ]; then
					tarOpts="${tarOpts}j";
				fi
				tarOpts="${tarOpts}f";
				if [ "xY" = "x$make_files" ] && [ "xY" = "x$make_upload" ]; then
					cd $documentRoot;
					if [ "xY" = $use_pipe ]; then
						printf "Making full files backup..." 1>&2;
						tar $tarOpts - $tarExcludes ./;
						return_status=$?;
						if [ "x0" = "x$return_status" ]; then echo "OK" 1>&2; fi
					else
						printf "Making full files backup...";
						tar $tarOpts ${backupFilePath}.all.$tar_file_ext $tarExcludes ./;
						return_status=$?;
						if [ "x0" = "x$return_status" ]; then echo "OK"; fi
					fi
					cd $CWD;
				elif [ "xY" = "x$make_files" ]; then
					cd $documentRoot;
					if [ "xY" = "x$use_pipe" ]; then
						printf "Making bitrix program files backup..." 1>&2;
						tar $tarOpts - $tarExcludes --exclude=./upload ./;
						return_status=$?;
						if [ "x0" = "x$return_status" ]; then echo "OK" 1>&2; fi
					else
						printf "Making bitrix program files backup...";
						tar $tarOpts ${backupFilePath}.files.$tar_file_ext $tarExcludes --exclude=./upload ./;
						return_status=$?;
						if [ "x0" = "x$return_status" ]; then echo "OK"; fi
					fi
					cd $CWD;
				elif [ "xY" = "x$make_upload" ]; then
					cd $documentRoot;
					if [ "xY" = "x$use_pipe" ]; then
						printf "Making bitrix upload backup..." 1>&2;
						tar $tarOpts - $tarExcludes \
							--exclude=./upload/resize_cache \
							--exclude=./upload/1c_exchange \
							--exclude=./upload/1c_catalog \
							./upload;
						return_status=$?;
						if [ "x0" = "x$return_status" ]; then echo "OK" 1>&2; fi
					else
						printf "Making bitrix upload backup...";
						tar $tarOpts ${backupFilePath}.upload.$tar_file_ext $tarExcludes \
							--exclude=./upload/resize_cache \
							--exclude=./upload/1c_exchange \
							--exclude=./upload/1c_catalog \
							./upload;
						return_status=$?;
						if [ "x0" = "x$return_status" ]; then echo "OK"; fi
					fi
					cd $CWD;
				fi
			fi
			exit $return_status;
		;;
		*)
			show_help;
			shift;
		;;
	esac
done
