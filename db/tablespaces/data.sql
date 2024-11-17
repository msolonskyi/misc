create bigfile tablespace DATA datafile '/u01/app/oracle/oradata/XE/data.dbf' size 256m
    autoextend on next 10m maxsize unlimited extent management local uniform size 64k logging segment space management auto;
