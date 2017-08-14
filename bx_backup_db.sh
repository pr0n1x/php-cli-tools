#!/bin/bash

# config
documentRoot="${HOME}/www/domain.ru";
backupFolder="${HOME}/backup"
backupName="domain.ru"


# vars
currentTime=`date +%Y-%m-%d-%H%M`;
backupFileName="${backupName}.db-${currentTime}.sql"
backupFilePath="$backupFolder/$backupFileName"
dbUser=`cat $documentRoot/bitrix/php_interface/dbconn.php | grep '\$DB' | grep '\$DBLogin' | awk -F '=' '{print $2}' | awk -F '"' '{print $2}'`;
dbPass=`cat $documentRoot/bitrix/php_interface/dbconn.php | grep '\$DB' | grep '\$DBPassword' | awk -F '=' '{print $2}' | awk -F '"' '{print $2}'`;
dbName=`cat $documentRoot/bitrix/php_interface/dbconn.php | grep '\$DB' | grep '\$DBName' | awk -F '=' '{print $2}' | awk -F '"' '{print $2}'`;
dbUseUtf8=`cat $documentRoot/bitrix/php_interface/dbconn.php | grep 'define(' | grep 'BX_UTF' | awk -F ',' '{print $2}' | awk -F ')' '{print $1}' | sed -e 's/[[:space:]]*//'`

dbDefaultCharset=cp1251
if [ "_true_" = "_${dbUseUtf8}_" ]; then
	dbDefaultCharset=utf8
fi

#echo "mysqldump -u$dbUser -p$dbPass $dbName --default-character-set=$dbDefaultCharset > $backupFilePath && gzip $backupFilePath"
mysqldump -u$dbUser -p$dbPass $dbName --default-character-set=$dbDefaultCharset > $backupFilePath && gzip $backupFilePath
