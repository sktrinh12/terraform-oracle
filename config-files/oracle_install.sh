#!/bin/bash

ORACLE_HOME="/u01/app/oracle/product/19.3/db_home"
TMP_HOME=/home/oracle
BACKUP=/orabackup/ORA_DM
ORA_DATA=/oradata/ORA_DM
S3B=DevOps/rman_backups
AWS=/usr/local/bin/aws
<<<<<<< HEAD
PINPOINT='C\\\$PINPOINT'
FILE_NAME=reindex.lst
LICENSE='LICENSE_NUMBER'
=======
>>>>>>> parent of 3036307 (re-index dotmatics pinpoint and download lib file)

# set -x enables a mode of the shell where all executed commands are printed to the terminal
set -x

# install required packages
sudo yum update -y
sudo yum install -y yum-utils oracle-database-preinstall-19c epel-release jq rlwrap

# download & install aws cli
cd /tmp
curl -LJO "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
unzip awscli-exe-linux-x86_64.zip
sudo ./aws/install
eval "echo \"oracle  ALL=(ALL) NOPASSWD:ALL\" | tee \"/etc/sudoers.d/oracle\""
sudo rm awscli-exe-linux-x86_64.zip
mkdir -p $ORACLE_HOME
chown -R oracle:oinstall /u01
chmod -R 775 /u01
rm -f $TMP_HOME/.bash_profile

# create bash_profile
echo <<EOF >>$TMP_HOME/.bash_profile
# .bash_profile
# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi
# User specific environment and startup programs
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.3/db_home
export ORACLE_SID=orcl_dm
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib
export NLS_LANG=american_america.al32utf8
export NLS_DATE_FORMAT="yyyy-mm-dd:hh24:mi:ss"
PATH=$PATH:$HOME/.local/bin:$ORACLE_HOME/bin
export PATH

alias sqlp='rlwrap sqlplus / as sysdba'
alias rman='rlwrap rman target /'
EOF

$AWS s3 cp s3://fount-data/DevOps/LINUX.X64_193000_db_home.zip $TMP_HOME
$AWS s3 cp s3://fount-data/DevOps/oracle_silent_install $TMP_HOME
$AWS s3 cp s3://fount-data/DevOps/tnsnames.ora $TMP_HOME
$AWS s3 cp s3://fount-data/DevOps/listener.ora $TMP_HOME
chmod +x $TMP_HOME/oracle_silent_install
chown oracle:oinstall $TMP_HOME/.bash_profile
sed -i "s/_HOSTNAME_/$HOSTNAME/g" $TMP_HOME/tnsnames.ora
sed -i "s/_HOSTNAME_/$HOSTNAME/g" $TMP_HOME/listener.ora

# install oracle 19c as oracle user
echo "change to oracle user"
sudo -i -u oracle bash <<EOF
        source $TMP_HOME/.bash_profile
        echo $ORACLE_HOME
        mv $TMP_HOME/LINUX.X64_193000_db_home.zip $ORACLE_HOME
        cd $ORACLE_HOME
        unzip -qo LINUX.X64_193000_db_home.zip
        sh $TMP_HOME/oracle_silent_install
				exit 0
EOF

# configure and change ownership
echo "done running as oracle user"
sudo /u01/app/oraInventory/orainstRoot.sh
sudo $ORACLE_HOME/root.sh
mv $TMP_HOME/*.ora $ORACLE_HOME/network/admin
# add port rule to firewall
firewall-cmd --zone=public --add-port=1521/tcp --permanent
firewall-cmd --reload
mkdir -p $BACKUP/archivelogs $BACKUP/autobackup
mkdir -p $ORA_DATA/controlfile $ORA_DATA/datafile
mkdir -p $ORACLE_HOME/admin/ora_dm/adump
chown -R oracle:oinstall $ORACLE_HOME/admin/ora_dm/adump
chown -R oracle:oinstall $BACKUP
chown -R oracle:oinstall $ORA_DATA

# use aws cli to get latest backup directory on s3
newest_file=$($AWS s3api list-objects-v2 \
	--bucket fount-data \
	--prefix $S3B/ \
	--query 'sort_by(Contents, &LastModified)[-1]' | jq -r '.Key')
echo $newest_file
echo

newest_folder=$(echo $newest_file | sed -E "s|$S3B||g" | awk -F/ '{print FS $2}')
echo $newest_folder # contains '/' already
echo

# download newest backup
$AWS s3 cp s3://fount-data/$S3B$newest_folder $BACKUP/autobackup$newest_folder --recursive --quiet
mv $BACKUP/autobackup$newest_folder/spfileorcl_dm.ora $ORACLE_HOME/dbs/
mkdir -p $BACKUP/archivelogs/$DATE
mv $BACKUP/autobackup$newest_folder/archivelogs/* $BACKUP/archivelogs/$DATE

# ensure file path in init file is correct
# sed -i -E 's|(LOCATION=\/orabackup\/)|\1ORA_DM\/|g' $ORACLE_HOME/dbs/spfileorcl_dm.ora

# startup
sudo -i -u oracle bash <<EOF
sqlplus / as sysdba <<EOL
  startup NOMOUNT pfile=$ORACLE_HOME/dbs/spfileorcl_dm.ora;
  exit
EOL
EOF

# RMAN commands
sudo -i -u oracle bash 2>/dev/null <<EOF
rman target / <<EOL
  restore controlfile from autobackup;
  alter database mount;
  crosscheck backup;
  delete noprompt expired backup;
  catalog start with '${BACKUP}/archivelogs${newest_folder}' noprompt;
  crosscheck archivelog all;
  change archivelog all validate;
  restore database;
  recover database;
  exit
EOL
EOF 

 

# alter db & test
sudo -i -u oracle bash <<EOF
sqlplus / as sysdba <<'EOL'
  alter database open resetlogs;
  select name, open_mode from v\$database;
<<<<<<< HEAD
	SET heading OFF;
	SET linesize 1000;
	SET pagesize 1000;
	spool '$FILE_NAME';
	select 'sqlplus -L ' ||lower(owner) ||'/' ||CASE WHEN REGEXP_LIKE(owner, 'pinpoint', 'i') THEN 'pinpoint' WHEN REGEXP_LIKE(owner, 'gateway', 'i') THEN 'dataowner' END ||'@${HOSTNAME}'||':1521/ora_dm'||',drop index '||i.index_name||' force;,create index '||i.index_name||' on '||i.table_name||'('||c.column_name||') indextype is ${PINPOINT}.chm;' from all_indexes i, all_ind_columns c where i.index_name = c.index_name and i.ITYP_OWNER = '${PINPOINT}' and i.ITYP_NAME = 'CHM' ORDER BY OWNER;
	spool off;
	exit
	EOL
	sqlplus c\$pinpoint/pinpoint@$HOSTNAME:1521/ora_dm <<EOI
	create or replace library dotmatics_lib as '$ORACLE_HOME/lib/libpinpoint_lnx_64_2.4.so';/
	delete from options where name='license';
	insert into options(name, value) values('license', '$LICENSE');
	commit;
	exit
	EOI
=======
  select * from c\$pinpoint.reg_data fetch next 1 rows only;
  exit
>>>>>>> parent of 3036307 (re-index dotmatics pinpoint and download lib file)
EOL
EOF

# start listener
sudo -i -u oracle bash <<<'lsnrctl start'

# start cron service
sudo systemctl start crond.service
mkdir -p $BACKUP/bkpscripts
# echo "0 5 * * 0-5 /orabackup/bkpscripts/full_backup.sh" >>cron_full_backup
# crontab cron_full_backup

echo "complete!"
