#!/bin/bash

# XE
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/11.2.0/xe
export LD_LIBRARY_PATH=$ORACLE_HOME/lib
export PATH=/bin:/usr/bin:/usr/openwin/bin:/usr/dt/bin:/usr/ucb:/etc:$ORACLE_HOME/OPatch:$ORACLE_HOME/bin

export ORACLE_SID="xe"
export ORACLE_UNQNAME="xe"

DT=`date '+%Y%m%d'`
path=/u01/app/oracle/backup/dmp/

db=xe

time expdp system/b1234567890@${db} DIRECTORY=dmpdir flashback_time=systimestamp FULL=y DUMPFILE=${db}_${DT}.dmp LOGFILE=${db}_${DT}.log 2>&1 | tee -a ${path}${db}_${DT}.log

echo "Begin of archiving..." | tee -a ${path}${db}_${DT}.log

time 7za a -mx=5 -m0=bzip2 -mmt=1 ${path}${db}_${DT} ${path}${db}_${DT}.dmp 2>&1 | tee -a ${path}${db}_${DT}.log

echo "Export and archiving is end. :)" | tee -a ${path}${db}_${DT}.log

rm ${path}${db}_${DT}.dmp
