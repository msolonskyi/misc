-- create directory 
create or replace directory dmpdir
  as '/u01/app/oracle/backup/dmp';
grant read, write on directory dmpdir to system;