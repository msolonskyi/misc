#!/bin/bash

# XE
export ORACLE_BASE=/u01/app/oracle

export ORACLE_HOME=$ORACLE_BASE/product/11.2.0/xe
export LD_LIBRARY_PATH=$ORACLE_HOME/lib
export PATH=/bin:/usr/bin:/usr/openwin/bin:/usr/dt/bin:/usr/ucb:/etc:$ORACLE_HOME/OPatch:$ORACLE_HOME/bin

export ORACLE_SID="xe"
export ORACLE_UNQNAME="xe"

sqlplus system/b1234567890@${ORACLE_SID} << EOF

exec dbms_stats.gather_database_stats;

EOF


