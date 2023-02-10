#! /bin/sh
export DATE=$(date +%Y_%m_%d)
export ORACLE_HOME=/u01/app/oracle/product/19.3/db_home
export ORACLE_SID=orcl_dm
export PATH=$PATH:$ORACLE_HOME/bin
BACKUP='/orabackup/ORA_DM'
S3B=DevOps/rman_backups
AWS=/usr/local/bin/aws

fullbackup() {
	rman log="${BACKUP}/bkpscripts/b_${DATE}_full_bkp.log" <<EOF
connect target /
set echo on;
run
{
backup incremental level 0 
cumulative device type disk 
format '${BACKUP}/autobackup/full_dm_%d_%T.bkp'
tag 'ORA_DM' database;
backup device type disk tag 'ORA_DM'
format '${BACKUP}/autobackup/full_dm_archivelog_%d_%T.bkp'
archivelog not backed up delete all input;
delete noprompt obsolete device type disk;
}
exit
EOF
}

pfile() {
	rm -rf $BACKUP/autobackup/*
	sqlplus / as sysdba <<EOF > "pfile_output"
		create pfile='${BACKUP}/autobackup/pfileorcl_dm.ora' from memory;
	EOF
	if grep -q "ORA-" "pfile_output" || grep -q "SP2-" "pfile_output"; then
				return 1
	else return 0
	fi
}

# pfile_try() {
# 	sqlplus / as sysdba <<EOF
#   create pfile='${BACKUP}/autobackup/pfileorcl_dm.ora' from memory;
# 	shutdown immediate;
# 	startup pfile='${ORACLE_HOME}/dbs/initorcl_dm.ora';
# 	create spfile from pfile;
# 	EOF
# }

uploadbackup() {
	check=$($AWS s3api list-objects-v2 --bucket fount-data --prefix "${S3B}/${DATE}" --query 'Contents[]')
	first_string=$(echo $check | awk '{print $1}')
	echo $first_string
	[[ $first_string == 'null' ]] && {
		echo "creating prefix (folder) ${DATE}"
		$AWS s3api put-object --bucket fount-data --key $S3B/$DATE/
	}
	# upoad files to s3
	$AWS s3 cp $BACKUP/autobackup/ s3://fount-data/$S3B/$DATE/ --quiet --recursive

	# tag backups/archivelogs
	for file in $($AWS s3 ls s3://fount-data/$S3B/$DATE/ --recursive | awk 'NR>=1{print $4}'); do
		$AWS s3api put-object-tagging \
			--bucket fount-data \
			--key "${file}" \
			--tagging '{"TagSet": [{ "Key": "Name", "Value": "RMAN" }]}'
		#echo "${AWS} s3api put-object-tagging --bucket fount-data --key ${file}"
	done
}

#MAIN
pfile
exit_code=$?
echo $exit_code
# if [ $exit_code -eq 1 ]; then
# 	pfile_try
# fi
fullbackup
uploadbackup
