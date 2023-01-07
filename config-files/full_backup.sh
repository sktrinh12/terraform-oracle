#! /bin/sh
export DATE=$(date +%Y_%m_%d)
export TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
export ORACLE_HOME=/u01/app/oracle/product/19.3/db_home
export ORACLE_SID=orcl_dm
export PATH=$PATH:$ORACLE_HOME/bin
BACKUP='/orabackup/ORA_DM'
S3B=DevOps/rman_backups
AWS=/usr/local/bin/aws

fullbackup() {
	rman log=$BACKUP/bkpscripts/b_$DATE_full_bkp.log <<EOF

connect target /

set echo on;

run
{

backup incremental level 0 
cumulative device type disk 
format '${BACKUP}/autobackup/${DATE}/%U.bkp'
tag 'ORA_DM' database;
backup device type disk tag 'ORA_DM' 
format = '${BACKUP}/archivelogs/${DATE}/%d_%u' 
archivelog all not backed up delete all input;
delete noprompt obsolete device type disk;
backup as copy current controlfile format '${BACKUP}/autobackup/${DATE}/ctlfile_%c.ctl'; 
}
exit
EOF
}

pfile() {
	mkdir -p $BACKUP/archivelogs/$DATE
	mkdir -p $BACKUP/autobackup/$DATE
	sqlplus / as sysdba <<EOF
		create spfile='${BACKUP}/autobackup/${DATE}/spfileorcl_dm.ora' from pfile='${ORACLE_HOME}/dbs/spfileorcl_dm.ora';
		exit
EOF
}

uploadbackup() {
	check=$($AWS s3api list-objects-v2 --bucket fount-data --prefix "${S3B}/${DATE}" --query 'Contents[]')
	first_string=$(echo $check | awk '{print $1}')
	echo $first_string
	[[ $first_string == 'null' ]] && {
		echo "creating prefix (folder) ${DATE}"
		$AWS s3api put-object --bucket fount-data --key $S3B/$DATE/archivelogs
	}
	# upoad files to s3
	$AWS s3 cp $BACKUP/autobackup/$DATE s3://fount-data/$S3B/$DATE/ --quiet --recursive --exclude 'o1_*'

	# tag backups/archivelogs
	for file in $($AWS s3 ls s3://fount-data/$S3B/$DATE/ --recursive | awk 'NR>=2{print $4}'); do
		$AWS s3api put-object-tagging \
			--bucket fount-data \
			--key $S3B/$DATE/$file \
			--tagging '{"TagSet": [{ "Key": "Name", "Value": "RMAN" }]}'
	done
}

#MAIN
pfile
fullbackup
uploadbackup
