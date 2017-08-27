#!/bin/sh
#
# if script named "bx_backup.domain.ru.sh"
# then config file must me named as "bx_backup.domain.ru.conf"
# config file example:
#
#  document_root="${HOME}/www/domain.ru";
#  backup_folder="${HOME}/backup"
#  backup_name="domain.ru"
#

self_dir=$(cd $(dirname $0); pwd;);
self_name=`basename $0`;
self_name=${self_name%.*};
current_time=`date +%Y-%m-%d-%H%M`;
CWD=`pwd`;

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
	echo "    --make-config      - Create config file for domain (virtual host)"
	echo "                         This options works only if it's alone"
}
OPTS=`getopt -o hpfuadwzjv --long 'help,pipe,files,upload,all,db,whole,gzip,zip,bzip2,bzip,tar-verbose,tar-perm,show-db-name,show-db-user,show-db-pass,show-db-charset,make-config' -n 'parse-options' -- $@`
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
show_db_charset="N";
make_config="N";
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
			show_db_charset="Y";
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
			echo "Whole backup is not implemented yet.";
			exit 1;
		;;
		-p | --pipe)
			use_pipe="Y";
			shift;
		;;
		--make-config)
			make_config="Y";
			shift;
		;;
		--)
			if [ "xY" = "x$make_config" ]; then
				echo $0;
				echo `realpath $0`;
				echo "Making config";
				#echo "Opts: $@";
				exit 0;
			fi
			
			if [ ! -f ${self_dir}/${self_name}.conf ]; then
				echo "Config file ${self_name}.conf not found";
				exit 1;
			fi

			source ${self_dir}/${self_name}.conf;

			if [ ! -d $document_root ]; then
				echo "Config error: Document root not found in config file" 1>&2;
				exit 1;
			fi
			if [ ! -d $backup_folder ]; then
				echo "Config error: Backup folder not found in config file" 1>&2;
				exit 1;
			fi
			backup_name=`echo $backup_name | sed 's/\ \	//g'`;
			if [ "x" = "x$backup_name" ]; then
				echo "Config error: Backup name does not set" 1>&2;
				exit 1;
			fi

			backup_filename="${backup_name}.bak-${current_time}"
			backup_filepath="$backup_folder/$backup_filename"
			db_user=`cat $document_root/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep '\$DB' | grep '\$DBLogin' | awk -F '=' '{print $2}' | awk -F '"' '{print $2}'`;
			db_pass=`cat $document_root/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep '\$DB' | grep '\$DBPassword' | awk -F '=' '{print $2}' | awk -F '"' '{print $2}'`;
			db_name=`cat $document_root/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep '\$DB' | grep '\$DBName' | awk -F '=' '{print $2}' | awk -F '"' '{print $2}'`;
			db_use_utf8=`cat $document_root/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep 'define(' | grep 'BX_UTF' | awk -F ',' '{print $2}' | awk -F ')' '{print $1}' | sed -e 's/[[:space:]]*//'`;
			db_default_charset=cp1251
			if [ "_true_" = "_${db_use_utf8}_" ]; then
				db_default_charset=utf8
			fi
			
			
			return_status=0;
			notPipeFileAndDb="Error: You can't make backup of files and database and use pushing to pipe at the same time";
			if [ "xY" = "x$use_pipe" ] && [ "xY" = "x$make_db" ] && [ "xY" = "x$make_files" ]; then
				echo $notPipeFileAndDb 1>&2;
				show_help 1>&2;
				exit 1;
			elif [ "xY" = "x$use_pipe" ] && [ "xY" = "x$make_db" ] && [ "xY" = "x$make_upload" ]; then
				echo $notPipeFileAndDb 1>&2;
				show_help 1>&2;
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
						echo "Database name: $db_name" 1>&2;
					else
						echo "Database name: $db_name";
					fi
				fi
				if [ "xY" = "x$show_db_user" ]; then
					if [ "xY" = "x$use_pipe" ]; then
						echo "Database user: $db_user" 1>&2;
					else
						echo "Database user: $db_user";
					fi
				fi
				if [ "xY" = "x$show_db_pass" ]; then
					if [ "xY" = "x$use_pipe" ]; then
						echo "Database password: $db_pass" 1>&2;
					else
						echo "Database password: $db_pass";
					fi
				fi
				if [ "xY" = "x$show_db_charset" ]; then
					if [ "xY" = "x$use_pipe" ]; then
						echo "Database charset: $db_default_charset" 1>&2;
					else
						echo "Database charset: $db_default_charset";
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
							mysqldump -u$db_user -p$db_pass $db_name --default-character-set=$db_default_charset | gzip
						elif [ "xY" = "x$use_bzip" ]; then
							mysqldump -u$db_user -p$db_pass $db_name --default-character-set=$db_default_charset | bzip2
						else
							mysqldump -u$db_user -p$db_pass $db_name --default-character-set=$db_default_charset
						fi
						return_status=$?;
						if [ "x0" = "x$return_status" ]; then echo "OK" 1>&2; fi
					else
						printf "Making database backup $compression_message...";
						if [ "xY" = "x$use_gzip" ]; then
							mysqldump -u$db_user -p$db_pass $db_name --default-character-set=$db_default_charset > ${backup_filepath}.db.sql && gzip ${backup_filepath}.db.sql;
						elif [ "xY" = "x$use_bzip" ]; then
							mysqldump -u$db_user -p$db_pass $db_name --default-character-set=$db_default_charset > ${backup_filepath}.db.sql && bzip2 ${backup_filepath}.db.sql;
						else
							mysqldump -u$db_user -p$db_pass $db_name --default-character-set=$db_default_charset > ${backup_filepath}.db.sql;
						fi
						return_status=$?;
						if [ "x0" = "x$return_status" ]; then echo "OK"; fi
					fi
				fi
				
				#make files backup
				tar_excludes="";
				tar_excludes="$tar_excludes --exclude=./bitrix/cache";
				tar_excludes="$tar_excludes --exclude=./bitrix/managed_cache";
				tar_excludes="$tar_excludes --exclude=./bitrix/stack_cache";
				tar_excludes="$tar_excludes --exclude=./bitrix/backup";
				tar_excludes="$tar_excludes --exclude=./bitrix/tmp";
				tar_excludes="$tar_excludes --exclude=./local/tmp";
				tar_excludes="$tar_excludes --exclude=./.idea";
				tar_excludes="$tar_excludes --exclude=./.git";
				tar_excludes="$tar_excludes --exclude=./*.tar";
				tar_excludes="$tar_excludes --exclude=./*.gz";
				tar_excludes="$tar_excludes --exclude=./*.bz";
				tar_excludes="$tar_excludes --exclude=./*.bz2";
				tar_excludes="$tar_excludes --exclude=./*.zip";
				tar_excludes="$tar_excludes --exclude=./*.rar";
				tar_excludes="$tar_excludes --exclude=./*.7z";
				tar_excludes="$tar_excludes --exclude=./*.lzma";
				tar_opts="c";
				if [ "xY" = "x$tar_verbose" ]; then
					tar_opts="${tar_opts}v";
				fi
				if [ "xY" = "x$use_gzip" ]; then
					tar_opts="${tar_opts}z";
				fi
				if [ "xY" = "x$use_bzip" ]; then
					tar_opts="${tar_opts}j";
				fi
				tar_opts="${tar_opts}f";
				if [ "xY" = "x$make_files" ] && [ "xY" = "x$make_upload" ]; then
					cd $document_root;
					if [ "xY" = $use_pipe ]; then
						printf "Making full files backup..." 1>&2;
						tar $tar_opts - $tar_excludes ./;
						return_status=$?;
						if [ "x0" = "x$return_status" ]; then echo "OK" 1>&2; fi
					else
						printf "Making full files backup...";
						tar $tar_opts ${backup_filepath}.all.$tar_file_ext $tar_excludes ./;
						return_status=$?;
						if [ "x0" = "x$return_status" ]; then echo "OK"; fi
					fi
					cd $CWD;
				elif [ "xY" = "x$make_files" ]; then
					cd $document_root;
					if [ "xY" = "x$use_pipe" ]; then
						printf "Making bitrix program files backup..." 1>&2;
						tar $tar_opts - $tar_excludes --exclude=./upload ./;
						return_status=$?;
						if [ "x0" = "x$return_status" ]; then echo "OK" 1>&2; fi
					else
						printf "Making bitrix program files backup...";
						tar $tar_opts ${backup_filepath}.files.$tar_file_ext $tar_excludes --exclude=./upload ./;
						return_status=$?;
						if [ "x0" = "x$return_status" ]; then echo "OK"; fi
					fi
					cd $CWD;
				elif [ "xY" = "x$make_upload" ]; then
					cd $document_root;
					if [ "xY" = "x$use_pipe" ]; then
						printf "Making bitrix upload backup..." 1>&2;
						tar $tar_opts - $tar_excludes \
							--exclude=./upload/resize_cache \
							--exclude=./upload/1c_exchange \
							--exclude=./upload/1c_catalog \
							./upload;
						return_status=$?;
						if [ "x0" = "x$return_status" ]; then echo "OK" 1>&2; fi
					else
						printf "Making bitrix upload backup...";
						tar $tar_opts ${backup_filepath}.upload.$tar_file_ext $tar_excludes \
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