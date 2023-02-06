#!/bin/bash

set -x
SCHEMA_NAME="C\\\$PINPOINT"
FILE_NAME='reindex.lst'
ORACLE_HOME=/u01/app/oracle/product/19.3/db_home


sudo -i -u oracle bash <<EOF
	sqlplus / as sysdba <<EOL
	SET heading OFF;
	SET linesize 1000;
	SET pagesize 1000;
	spool '$FILE_NAME';
	select 'sqlplus -L ' ||lower(owner) ||'/' ||CASE WHEN REGEXP_LIKE(owner, 'pinpoint', 'i') THEN 'pinpoint' WHEN REGEXP_LIKE(owner, 'gateway', 'i') THEN 'dataowner' END ||'@${HOSTNAME}'||':1521/ora_dm'||',drop index '||i.index_name||' force;,create index '||i.index_name||' on '||i.table_name||'('||c.column_name||') indextype is ${SCHEMA_NAME}.chm;' from all_indexes i, all_ind_columns c where i.index_name = c.index_name and i.ITYP_OWNER = '${SCHEMA_NAME}' and i.ITYP_NAME = 'CHM' ORDER BY OWNER;
	spool off;
	exit
	EOL
        sqlplus c\$pinpoint/pinpoint@$HOSTNAME:1521/ora_dm <<EOI
        create or replace library dotmatics_lib as '$ORACLE_HOME/lib/libpinpoint_lnx_64_2.4.so';/
        exit
        EOI
EOF

# remove anything that does not start with sqlplus
# remove carriage return \r
# remove white trailing leading spaces
# replace \$ with \\\$ to escape
sed -i '/^[^sqlplus]/d; s/\r//g; s/^[ \t]*//;s/[ \t]*$//; s/\$/\\$/g' $FILE_NAME 
