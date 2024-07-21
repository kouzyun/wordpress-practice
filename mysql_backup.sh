#!/bin/sh
set -eu

umask 077
period=5
dirpath='/root/backup/mysql'
filename=`date +%y%m%d`
mysqldump  --defaults-extra-file=/etc/.my_sql.conf -p wordpress --events > $dirpath/$filename.sql
oldfile=`date --date "$period days ago" +%y%m%d`
rm -f $dirpath/$oldfile.sql