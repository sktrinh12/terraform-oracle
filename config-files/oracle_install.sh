#!/bin/bash

ORACLE_HOME=/opt/oracle/product/19c/db_home1
# ORACLE_HOME="/u01/app/oracle/product/19.3/db_home"
TMP_HOME=/home/oracle
BACKUP=/orabkp
# BACKUP=/orabackup
ORA_DATA=/oradata/ORA_DM
S3B=DevOps/rman_backups
AWS=/usr/local/bin/aws
PINPOINT='C\\\$PINPOINT'
FILE_NAME=reindex.lst
ORACLE_BASE=/opt/oracle
HOME_AWS=/home/ec2-user
IP_ADDR=$(cat $HOME_AWS/ip_addr)
# requires two arguments,
# 1) license string
# 2) newest or recovery date (folder name in s3)
LICENSE="$1" # the first argument passed from tf apply
RECOVERY_DATE="$2"
SNS_ARN="$3"

echo $LICENSE
echo $RECOVERY_DATE
echo $SNS_ARN

# set -x enables a mode of the shell where all executed commands are printed to the terminal
set -ex

# mount both ebs volumes
echo "starting ebs mount script ..."
sleep 60
mkfs -t ext4 /dev/xvdb
mkfs -t ext4 /dev/xvdc
mkdir /oradata
mkdir /orabkp
mount /dev/xvdb /oradata
echo "/dev/xvdb /oradata ext4 defaults,nofail 0 2" >>/etc/fstab
mount /dev/xvdc /orabkp
echo "/dev/xvdc /orabkp ext4 defaults,nofail 0 2" >>/etc/fstab

trap '/usr/local/bin/aws sns publish --topic-arn $SNS_ARN --message "[$IP_ADDR | $HOSTNAME] Error occurred while running the script: $BASH_COMMAND"' ERR

# install required packages
sudo yum update -y
sudo yum install -y yum-utils oracle-database-preinstall-19c jq wget

# install rlwrap
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -ivh epel-release-latest-7.noarch.rpm
sudo yum install -y rlwrap

# download & install aws cli
cd /tmp
curl -LJO "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
unzip awscli-exe-linux-x86_64.zip
sudo ./aws/install
eval "echo \"oracle  ALL=(ALL) NOPASSWD:ALL\" | tee \"/etc/sudoers.d/oracle\""
sudo rm awscli-exe-linux-x86_64.zip
mkdir -p $ORACLE_HOME
chown -R oracle:oinstall /opt
chmod -R 775 /opt
rm -f $TMP_HOME/.bash_profile

# create bash_profile
cat <<EOF >$TMP_HOME/.bash_profile
# .bash_profile
# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi
# User specific environment and startup programs
export ORACLE_BASE=${ORACLE_BASE}
export ORACLE_HOME=${ORACLE_HOME}
export ORACLE_SID=orcl_dm
export BACKUP=${BACKUP}/orabackup/ORA_DM
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib
export NLS_LANG=american_america.al32utf8
export NLS_DATE_FORMAT="yyyy-mm-dd:hh24:mi:ss"
PATH=\$PATH:\$HOME/.local/bin:\$ORACLE_HOME/bin
export PATH

alias sqlp='rlwrap sqlplus / as sysdba'
alias rmanrl='rlwrap rman target /'
EOF

$AWS s3 cp s3://fount-data/DevOps/libpinpoint_lnx_64_2.4.so $TMP_HOME
$AWS s3 cp s3://fount-data/DevOps/LINUX.X64_193000_db_home.zip $TMP_HOME
$AWS s3 cp s3://fount-data/DevOps/oracle_silent_install $TMP_HOME
$AWS s3 cp s3://fount-data/DevOps/tnsnames.ora $TMP_HOME
$AWS s3 cp s3://fount-data/DevOps/listener.ora $TMP_HOME
chmod +x $TMP_HOME/oracle_silent_install
chown oracle:oinstall $TMP_HOME/.bash_profile $TMP_HOME/libpinpoint_lnx_64_2.4.so
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
sudo $ORACLE_BASE/oraInventory/orainstRoot.sh
sudo $ORACLE_HOME/root.sh
mv $TMP_HOME/*.ora $ORACLE_HOME/network/admin
mv $TMP_HOME/libpinpoint_lnx_64_2.4.so $ORACLE_HOME/lib
# add port rule to firewall
firewall-cmd --zone=public --add-port=1521/tcp --permanent
firewall-cmd --reload

if [ $RECOVERY_DATE == "newest" ]; then
	# use aws cli to get latest backup directory on s3
	newest_file=$($AWS s3api list-objects-v2 \
		--bucket fount-data \
		--prefix $S3B/ \
		--query 'sort_by(Contents, &LastModified)[-1]' | jq -r '.Key')
	newest_folder=$(echo $newest_file | sed -E "s|$S3B||g" | awk -F/ '{print FS $2}')
	echo $newest_folder # contains '/' already
	echo
else
	newest_folder="/${RECOVERY_DATE}"
fi

mkdir -p $BACKUP/orabackup/ORA_DM/autobackup$newest_folder \
	$BACKUP/archivelogs \
	$BACKUP/recv_area/ORA_DM/onlinelog \
	$ORA_DATA/controlfile \
	$ORA_DATA/datafile \
	$ORA_DATA/onlinelog \
	$ORACLE_BASE/admin/ora_dm/adump

chown -R oracle:oinstall $ORACLE_BASE
chown -R oracle:oinstall $BACKUP
chown -R oracle:oinstall $ORA_DATA

# download newest backup
$AWS s3 cp s3://fount-data/$S3B$newest_folder $BACKUP/orabackup/ORA_DM/autobackup --recursive --quiet

# move full backup cron job file
sudo chown oracle:oinstall $HOME_AWS/full_backup.sh
sudo chmod +x $HOME_AWS/full_backup.sh
mv $HOME_AWS/full_backup.sh $BACKUP/orabackup/ORA_DM/bkpscripts

# startup
sudo -i -u oracle bash <<EOF
sqlplus / as sysdba <<EOL
  startup NOMOUNT pfile='${BACKUP}/orabackup/ORA_DM/autobackup/pfileorcl_dm.ora';
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
  catalog start with '${BACKUP}/orabackup/ORA_DM/autobackup' noprompt;
  crosscheck archivelog all;
  change archivelog all validate;
  restore database;
  recover database;
  exit
EOL
EOF 
 

# alter db & generate reindex cmds 
sudo -i -u oracle bash <<EOF
sqlplus / as sysdba <<EOL
  alter database open resetlogs;
	SET heading OFF;
	SET linesize 1000;
	SET pagesize 1000;
	spool '$FILE_NAME';
	select 'sqlplus -L ' ||lower(owner) ||'/' ||CASE WHEN REGEXP_LIKE(owner, 'pinpoint', 'i') THEN 'pinpoint' WHEN REGEXP_LIKE(owner, 'gateway', 'i') THEN 'dataowner' WHEN REGEXP_LIKE(owner, 'ds3_userdata', 'i') THEN 'ds3_userdata' END ||'@${HOSTNAME}'||':1521/ora_dm'||',drop index '||i.index_name||' force;,create index '||i.index_name||' on '||i.table_name||'('||c.column_name||') indextype is ${PINPOINT}.chm;' from all_indexes i, all_ind_columns c where i.index_name = c.index_name and i.ITYP_OWNER = '${PINPOINT}' and i.ITYP_NAME = 'CHM' ORDER BY OWNER;
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
  exit
EOL
EOF

# remove sqlplus prompt from spool and add escape '$'
sed -i '/^[^sqlplus]/d; s/\r//g; s/^[ \t]*//;s/[ \t]*$//; s/\$/\\$/g' "${TMP_HOME}/${FILE_NAME}"

# start listener
sudo -i -u oracle bash <<<'lsnrctl start'

sleep 90

# read sql statements from file (re-index pinpoint)
while IFS=',' read -r line; do
	IFS=',' read -r -a commands <<<"$line"
	if [[ -n "$line" ]]; then
		sudo -i -u oracle bash <<EOF
${commands[0]} <<EOL
${commands[1]}
${commands[2]}
exit
EOL
EOF
	fi
done <"$TMP_HOME/$FILE_NAME"

# start cron service
sudo systemctl start crond.service
# echo "0 5 * * 0-5 /orabackup/bkpscripts/full_backup.sh" >>cron_full_backup
# crontab cron_full_backup

echo "complete!"
/usr/local/bin/aws sns publish --topic-arn $SNS_ARN --message "[$IP_ADDR | $HOSTNAME] Success restoring database!"
