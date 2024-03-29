#!/bin/bash
#
# if script named "bx_backup.domain.ru.sh"
# then config file must me named as "bx_backup.domain.ru.conf"
# config file example:
#
#  backup_name="domain.ru"
#  document_root="${HOME}/www/domain.ru";
#  backup_folder="${HOME}/backup"
#
realpath=`which realpath 2>/dev/null`;
if [ "x" = "x$realpath" ]; then
	realpath="readlink -f"
fi
self_dir=$(cd $(dirname $0); pwd;);
self_name=`basename $0`;
self_name=${self_name%.*};
self_real_path=`$realpath $0`;
self_real_name=`basename $self_real_path`;
self_real_name=${self_real_name%.*};
current_time=`date +%Y-%m-%d-%H%M`;
CWD=`pwd`;

show_help() {
	echo "Usage: ${self_name} [options]";
	echo "    -h | --help               - Show this help message";
	echo "    -p | --pipe               - Do not create file and push data to stdout";
	echo "    -f | --files              - Create backup of the bitrix program files";
	echo "    -u | --upload             - Create backup of the bitrix upload folder";
	echo "    -a | --all-files          - Create full backup except database dump file :)";
	echo "    -w | --whole              - Not implemented yet. Create whole files to backup with database";
	echo "    -d | --db                 - Backup database";
	echo "    --skip-table=<db_name>    - Excludes table data from the database dump.";
	echo "    --ignore-table=<db_name>  - Excludes table data and structure from the database dump.";
	echo "                                 Options --skip-table and --ignore-table can be used several times";
	echo "    --lock-db                 - Lock database for guaranty of backup consistency";
	echo "    --skip-bx-stat            - Exclude data of \"statistics\" module from database dump";
	echo "    --skip-bx-search-index    - Exclude search index data from database dump";
	echo "    --skip-bx-event-log       - Exclude event log data from database dump";
	echo "    --skip-bx-huge            - alias of: --skip-bx-stat --skip-bx-search-index --skip-bx-event-log";
	echo "    -z | --gzip               - Use gzip compression";
	echo "    -j | --bzip               - Use bzip2 compression";
	echo "    -v | --tar-verbose        - Show tar report (tar option -v)";
	echo "    --tar-perm                - Save files permissions (tar option -p)";
	echo "    --show-db-name            - mmm.. this option shows database name...";
	echo "    --show-db-user            - mmm.. you know";
	echo "    --show-db-pass            - Ah! Don't use this option in public places!";
	echo "    --show-db-charset         - Ok. This option you can use any where.";
	echo "    --sleep=<seconds>         - Пауза в секундах перед стартом.";
	show_mk_conf_help;
}
show_mk_conf_help() {
	echo "    --make-config     - Create config file for domain (virtual host) and backup script symlink";
	echo "                        --make-config <domain-name> [document root path] [backup folder path]";
	echo "                        Example:";
	echo "                        --make-config domain.ru ~/ext_www/domain.ru ~/backup";
}
OPTS=`getopt -o hpfuadwzjv --long 'help,pipe,files,upload,all,db,whole,gzip,zip,bzip2,bzip,tar-verbose,tar-perm,show-db-name,show-db-user,show-db-pass,show-db-charset,make-config,sleep::,ignore-table:,lock-db,skip-table:,skip-bx-stat,skip-bx-search-index,skip-bx-event-log,skip-bx-huge' -n 'parse-options' -- $@`
#echo "eval set -- $OPTS";
#exit;
if [ $? != 0 ] ; then show_help >&2 ; exit 1 ; fi
eval set -- $OPTS;
if [ "x--" = "x$1" ]; then
	# if first argument is delimiter "--", then flags are not present. Showing help.
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
sleep_seconds="0";
db_ingore_table="";
db_no_data_table="";
db_lock="N";
db_skip_bx_stat="N";
db_skip_bx_search_index="N";
db_skip_bx_event_log="N";
db_skip_bx_huge="N"

while (( $# )); do
	#echo "Opts: $@ | count:$#";
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
		--ignore-table)
			db_ingore_table="$db_ingore_table --ignore-table=#db_name#.$2"
			shift;
			shift;
		;;
		--skip-table)
			db_ingore_table="$db_ingore_table --ignore-table=#db_name#.$2"
			db_no_data_table="$db_no_data_table $2"
			shift;
			shift;
		;;
		--lock-db)
			db_lock="Y";
			shift;
		;;
		--skip-bx-stat)
			db_skip_bx_stat="Y";
			shift;
		;;
		--skip-bx-search-index)
			db_skip_bx_search_index="Y";
			shift;
		;;
		--skip-bx-event-log)
			db_skip_bx_event_log="Y";
			shift;
		;;
		--skip-bx-huge)
			db_skip_bx_stat="Y";
			db_skip_bx_search_index="Y";
			db_skip_bx_event_log="Y";
			shift;
		;;
		-a | --all)
			make_upload="Y";
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
		--sleep)
			if [ "x$2" != "x0" ]; then
				sleep_seconds=`expr "$2" + 0 2>/dev/null || echo "0"`;
			fi
			shift;
			shift;
		;;
		--)
			shift;
			break;
		;;
		*)
			show_help;
			shift;
		;;
	esac
done

sleep $sleep_seconds;
if [ "xY" = "x$make_config" ]; then
	echo "Making config.";
	#echo "Opts: $@";
	mk_conf_domain=`echo $1 | sed 's/[[:space:]]//g'`
	mk_conf_document_root=`echo $2 | sed 's/[[:space:]]//g' | sed "s#${HOME}#\\\$\{HOME\}#g"`;
	mk_conf_backup_folder=`echo $3 | sed 's/[[:space:]]//g' | sed "s#${HOME}#\\\$\{HOME\}#g"`;
	if [ "x" = "x$mk_conf_domain" ]; then
		echo "Error: You should to set domain name" 1>&2;
		show_mk_conf_help 1>&2;
		exit 1;
		#mk_conf_domain="domain.ru";
	fi
	if [ "x" = "x$mk_conf_document_root" ]; then
		mk_conf_document_root="\${HOME}/ext_www/${mk_conf_domain}"
	fi
	if [ "x" = "x$mk_conf_backup_folder" ]; then
		mk_conf_backup_folder="\${HOME}/backup"
	fi
	mk_conf_new_self=${self_dir}/${self_name}.${mk_conf_domain}.sh;
	mk_conf_new_conf=${self_dir}/${self_name}.${mk_conf_domain}.conf;
	# echo "mk_conf_domain=${mk_conf_domain}";
	# echo "mk_conf_document_root=${mk_conf_document_root}";
	# echo "mk_conf_backup_folder=${mk_conf_backup_folder}";
	# echo "mk_conf_new_self=${mk_conf_new_self}";
	# echo "mk_conf_new_conf=${mk_conf_new_conf}";
	# exit;
	
	if [ -f ${mk_conf_new_self} ]; then
		echo "Warning: new domain backup script symlink already exists." 1>&2;
		if [ ! -L ${mk_conf_new_self} ]; then
			echo "         but... this file is not a symlink to real backup script!"
			echo "         You should delete it and run --make-config again."
		fi
	else
		ln -s ${self_real_path} ${mk_conf_new_self};
	fi
	if [ -f ${mk_conf_new_conf} ]; then
		echo "Warning: new domain config already exists." 1>&2;
	else
		cat <<EOF > ${mk_conf_new_conf};
backup_name="${mk_conf_domain}";
document_root="${mk_conf_document_root}";
backup_folder="${mk_conf_backup_folder}";

EOF
		mk_conf_editor=`which mcedit 2>/dev/null`;
		if [ "x" = "x${mk_conf_editor}" ]; then
			mk_conf_editor=`which nano 2>/dev/null`;
		fi
		if [ "x" = "x${mk_conf_editor}" ]; then
			mk_conf_editor=`which vim 2>/dev/null`;
		fi
		if [ "x" != "x${mk_conf_editor}" ]; then
			$mk_conf_editor $mk_conf_new_conf;
		fi
		
	fi
	exit 0;
fi

# check config
if [ ! -f ${self_dir}/${self_name}.conf ]; then
	echo "Error: Config file \"${self_name}.conf\" not found" 1>&2;
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

# read bitrix config
if [ ! -f $document_root/bitrix/php_interface/dbconn.php ]; then
	echo "Error: dbconn.php file not found ($document_root/bitrix/php_interface/dbconn.php)" 1>&2;
	exit 1;
fi
backup_filename="${backup_name}.bak-${current_time}"
backup_filepath="$backup_folder/$backup_filename"
db_host=`cat $document_root/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep '\$DB' | grep '\$DBHost' | awk -F '=' '{print $2}' | awk -F "[\"']" '{print $2}'`;
db_user=`cat $document_root/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep '\$DB' | grep '\$DBLogin' | awk -F '=' '{print $2}' | awk -F "[\"']" '{print $2}'`;
db_pass=`cat $document_root/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep '\$DB' | grep '\$DBPassword' | awk -F '=' '{print $2}' | awk -F "[\"']" '{print $2}'`;
db_name=`cat $document_root/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep '\$DB' | grep '\$DBName' | awk -F '=' '{print $2}' | awk -F "[\"']" '{print $2}'`;
db_use_utf8=`cat $document_root/bitrix/php_interface/dbconn.php | egrep -v '^[[:space:]]*(//|#)' | grep 'define(' | grep 'BX_UTF' | awk -F ',' '{print $2}' | awk -F ')' '{print $1}' | sed -e 's/[[:space:]]*//'`;
db_default_charset=cp1251
if [ "_true_" = "_${db_use_utf8}_" ]; then
	db_default_charset=utf8
fi


# check errors
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
elif [ "xN" = "x$make_db" ]\
	&& [ "xN" = "x$make_files" ]\
	&& [ "xN" = "x$make_upload" ]\
	&& [ "xN" = "x$show_db_name" ]\
	&& [ "xN" = "x$show_db_user" ]\
	&& [ "xN" = "x$show_db_pass" ]\
	&& [ "xN" = "x$show_db_charset" ];
then
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

	#make database backup
	if [ "xY" = "x$make_db" ]; then
		
		mysql_pass_cnf="[mysqldump]
host = ${db_host:-localhost}
port = ${db_port:-3306}
user = \"${db_user}\"
password = \"${db_pass}\"

[mysql]
host = ${db_host:-localhost}
port = ${db_port:-3306}
user = \"${db_user}\"
password = \"${db_pass}\"
"
		mysql_pass_cnf_dir="/tmp/bx_backup"
		if ! mkdir -p ${mysql_pass_cnf_dir} \
			|| ! test -w ${mysql_pass_cnf_dir};
		then
			echo "Using backup folder for mysql pass config";
			mysql_pass_cnf_dir=$backup_folder
		fi
		mysql_pass_cnf_filename="${backup_name}.pass.mysql.cnf"
		mysql_pass_cnf_file="${mysql_pass_cnf_dir}/${mysql_pass_cnf_filename}"
		
		echo "${mysql_pass_cnf}" > ${mysql_pass_cnf_file}
		
		if [ "$?" != "0" ]; then
			echo "Using backup folder for mysql pass config";
			mysql_pass_cnf_dir=$backup_folder
		fi
		
		#echo ${mysql_pass_cnf_file}
		#cat ${mysql_pass_cnf_file}
		
		function get_all_bx_tables {
			echo 'SHOW TABLES;' \
			| mysql \
				--defaults-extra-file=$mysql_pass_cnf_file \
				--default-character-set=$db_default_charset \
				$db_name \
			| grep -v 'Tables_in_';
		}
		function get_bx_stat_tables {
			echo "SHOW TABLES like 'b_stat_%';" \
			| mysql \
				--defaults-extra-file=$mysql_pass_cnf_file \
				--default-character-set=$db_default_charset \
				$db_name \
			| grep -v 'Tables_in_';
		}
		function get_bx_event_log_tables {
			echo "SHOW TABLES like 'b_event_log';" \
			| mysql \
				--defaults-extra-file=$mysql_pass_cnf_file \
				--default-character-set=$db_default_charset \
				$db_name \
			| grep -v 'Tables_in_';
		}
		function get_bx_search_index_tables {
			local sql="
			SHOW TABLES
			FROM \`${db_name}\`
			WHERE
				\`Tables_in_${db_name}\` like 'b_search_%'
				AND \`Tables_in_${db_name}\` <> 'b_search_custom_rank'
				AND \`Tables_in_${db_name}\` <> 'b_search_phrase'
			";
			echo $sql \
			| mysql \
				--defaults-extra-file=$mysql_pass_cnf_file \
				--default-character-set=$db_default_charset \
				$db_name \
			| grep -v 'Tables_in_';
		}
		function get_huge_tables {
			local sql="
			SHOW TABLES
			FROM \`${db_name}\`
			WHERE
				( \`Tables_in_${db_name}\` like 'b_stat_%'
					or \`Tables_in_${db_name}\` like 'b_search_%'
					or \`Tables_in_${db_name}\` = 'b_event_log'
				)
				AND \`Tables_in_${db_name}\` <> 'b_search_custom_rank'
				AND \`Tables_in_${db_name}\` <> 'b_search_phrase'
			";
			echo $sql \
			| mysql \
				--defaults-extra-file=$mysql_pass_cnf_file \
				--default-character-set=$db_default_charset \
				$db_name \
			| grep -v 'Tables_in_';
		}
		
		skip_tables_list='';
		if [ "xY" = "x$db_skip_bx_huge" ]; then
			skip_tables_list="$skip_tables_list $(get_huge_tables)";
			returned=$?
		else
			if [ "xY" = "x$db_skip_bx_event_log" ]; then
				skip_tables_list="$skip_tables_list $(get_bx_event_log_tables)";
				returned=$?
			fi
			if [ "xY" = "x$db_skip_bx_stat" ]; then
				skip_tables_list="$skip_tables_list $(get_bx_stat_tables)";
				returned=$?
			fi
			if [ "xY" = "x$db_skip_bx_search_index" ]; then
				skip_tables_list="$skip_tables_list $(get_bx_search_index_tables)";
				returned=$?
			fi
		fi
		
		for skip_table in $skip_tables_list; do
			db_ingore_table="$db_ingore_table --ignore-table=#db_name#.$skip_table";
			db_no_data_table="$db_no_data_table $skip_table";
		done;
	
		if [ "x" != "x$db_ingore_table" ]; then
			db_ingore_table=`echo $db_ingore_table | sed "s/#db_name#/$db_name/g"`;
		fi
		if [ "x" != "x$db_no_data_table" ]; then
			db_no_data_table="--no-data $db_no_data_table";
		fi
		#echo "@db_ingore_table: |"$db_ingore_table"|" 1>&2 ;
		#echo "@db_no_data_table: |"$db_no_data_table"|" 1>&2;
		signe_transaction="--single-transaction";
		if [ "xY" = "x$db_lock" ]; then
			signe_transaction="";
		fi
		#echo "@signe_transaction: $signe_transaction";

		function make_mysql_dump {
			if [ "x" != "x$db_no_data_table" ]; then
				mysqldump \
					--defaults-extra-file=$mysql_pass_cnf_file \
					--default-character-set=$db_default_charset \
					$single_transaction \
					$db_name $db_ingore_table \
				&& mysqldump \
					--defaults-extra-file=$mysql_pass_cnf_file \
					--default-character-set=$db_default_charset \
					$single_transaction \
					$db_name $db_no_data_table;
				retval=$?
			else
				mysqldump \
					--defaults-extra-file=$mysql_pass_cnf_file \
					--default-character-set=$db_default_charset \
					$single_transaction \
					$db_name $db_ingore_table;
				retval=$?
			fi
			return $retval
		}
		
		compression_command=cat;
		if [ "xY" = "x$use_gzip" ]; then
			compression_command=gzip;
		elif [ "xY" = "x$use_bzip" ]; then
			compression_command=bzip2;
		fi
		if [ "xY" = "x$use_pipe" ]; then
			printf "Making database backup $compression_message..." 1>&2;
			if [ "xcat" != "x$compression_command" ]; then
				make_mysql_dump | $compression_command
			else
				make_mysql_dump
			fi
			return_status=$?;
			[ "x0" = "x$return_status" ] && echo "OK" 1>&2 || echo "ERROR" 1>&2;
		else
			printf "Making database backup $compression_message...";
			make_mysql_dump > ${backup_filepath}.db.sql
			return_status=$?;
			[ "x0" = "x$return_status" ] \
				&& [ "xcat" != "x$compression_command" ] \
				&& $compression_command ${backup_filepath}.db.sql;
			[ "x0" = "x$return_status" ] \
				&& echo "OK" || echo "ERROR"
		fi
		
		rm ${mysql_pass_cnf_file}
		
	fi
	
	#make files backup
	tar_excludes="";
	tar_opts="c";

	prepare_tar_backup() {
		tar_excludes="$tar_excludes --exclude=./bitrix/cache";
		tar_excludes="$tar_excludes --exclude=./bitrix/managed_cache";
		tar_excludes="$tar_excludes --exclude=./bitrix/stack_cache";
		tar_excludes="$tar_excludes --exclude=./bitrix/html_pages";
		tar_excludes="$tar_excludes --exclude=./bitrix/backup";
		tar_excludes="$tar_excludes --exclude=./bitrix/updates";
		tar_excludes="$tar_excludes --exclude=./bitrix/tmp";
		tar_excludes="$tar_excludes --exclude=./local/tmp";
		tar_excludes="$tar_excludes --exclude=./bitrix/log";
		tar_excludes="$tar_excludes --exclude=./local/log";
		tar_excludes="$tar_excludes --exclude=./bitrix/php_interface/dbconn.php";
		tar_excludes="$tar_excludes --exclude=./bitrix/.settings.php";
		tar_excludes="$tar_excludes --exclude=./.htaccess";
		tar_excludes="$tar_excludes --exclude=./urlrewrite.php";
		tar_excludes="$tar_excludes --exclude=./site.*/bitrix";
		tar_excludes="$tar_excludes --exclude=./site.*/upload";
		tar_excludes="$tar_excludes --exclude=./site.*/local";
		tar_excludes="$tar_excludes --exclude=./www.*/bitrix";
		tar_excludes="$tar_excludes --exclude=./www.*/upload";
		tar_excludes="$tar_excludes --exclude=./www.*/local";
		tar_excludes="$tar_excludes --exclude=./.idea";
		tar_excludes="$tar_excludes --exclude=./.vscode";
		tar_excludes="$tar_excludes --exclude=./.git";
		tar_excludes="$tar_excludes --exclude=./*.tar";
		tar_excludes="$tar_excludes --exclude=./*.gz";
		tar_excludes="$tar_excludes --exclude=./*.bz";
		tar_excludes="$tar_excludes --exclude=./*.bz2";
		tar_excludes="$tar_excludes --exclude=./*.zip";
		tar_excludes="$tar_excludes --exclude=./*.rar";
		tar_excludes="$tar_excludes --exclude=./*.7z";
		tar_excludes="$tar_excludes --exclude=./*.lzma";
		tar_excludes="$tar_excludes --exclude=./*.mysql.cnf";
		
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

		cd $document_root;
		local message="$1";
		local use_pipe="$2";
		[ "xY" = "x$use_pipe" ] && printf "$message" 1>&2 || printf "$message";
		cp bitrix/.settings.php bitrix/.settings.restore.php
		cp bitrix/php_interface/dbconn.php bitrix/php_interface/dbconn.restore.php
		[ -f .htaccess ] && cp .htaccess .htaccess.restore
		[ -f urlrewrite.php ] && cp urlrewrite.php urlrewrite.restore.php
	}

	post_tar_backup() {
		local tar_exit_status="$1";
		local use_pipe="$2";
		rm bitrix/.settings.restore.php
		rm bitrix/php_interface/dbconn.restore.php
		[ -f .htaccess.restore ] && rm .htaccess.restore
		[ -f urlrewrite.restore.php ] && rm urlrewrite.restore.php
		if [ "x0" = "x$tar_exit_status" ]; then
			[ "xY" = "x$use_pipe" ] && echo "OK" 1>&2 || echo "OK";
		fi
		cd $CWD;
	}

	if [ "xY" = "x$make_files" ] && [ "xY" = "x$make_upload" ]; then
		prepare_tar_backup "Making full files backup..." "$use_pipe";
		if [ "xY" = "x$use_pipe" ]; then
			tar $tar_opts - $tar_excludes ./;
		else
			tar $tar_opts ${backup_filepath}.all.$tar_file_ext $tar_excludes ./;
		fi
		return_status=$?;
		post_tar_backup "$return_status" "$use_pipe"
	elif [ "xY" = "x$make_files" ]; then
		prepare_tar_backup "Making bitrix program files backup $compression_message..." "$use_pipe";
		if [ "xY" = "x$use_pipe" ]; then
			tar $tar_opts - $tar_excludes --exclude=./upload ./;
		else
			tar $tar_opts ${backup_filepath}.files.$tar_file_ext $tar_excludes --exclude=./upload ./;
		fi
		return_status=$?;
		post_tar_backup "$return_status" "$use_pipe"
	elif [ "xY" = "x$make_upload" ]; then
		tar_upload_excludes="";
		tar_upload_excludes="$tar_upload_excludes --exclude=./upload/resize_cache";
		tar_upload_excludes="$tar_upload_excludes --exclude=./upload/1c_exchange";
		tar_upload_excludes="$tar_upload_excludes --exclude=./upload/1c_catalog";
		prepare_tar_backup "Making bitrix upload backup $compression_message..." "$use_pipe";
		if [ "xY" = "x$use_pipe" ]; then
			tar $tar_opts - $tar_excludes $tar_upload_excludes ./upload;
		else
			tar $tar_opts ${backup_filepath}.upload.$tar_file_ext $tar_excludes $tar_upload_excludes ./upload;
		fi
		return_status=$?;
		post_tar_backup "$return_status" "$use_pipe";
	fi
fi
exit $return_status;
