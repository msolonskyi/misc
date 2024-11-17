#!/bin/bash

#DIR=/mnt/emc1raid51s6/oracle/backup/dmp # путь к папке откуда удалять файлы
DIR=/u01/app/oracle/backup/dmp
#LOG_PATH=./go.log	# путь к файлу с логом
DAYS=30			# удалять файлы старше X дней
FIND=`which find`	# находим полный путь к комаде find
echo "Path: "${DIR}
${FIND} $DIR -type f -mtime +$DAYS -exec ls -lh {} \; -exec rm -rf {} \; 2>&1
