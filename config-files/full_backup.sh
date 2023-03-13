#! /bin/sh
export DATE=$(date +%Y_%m_%d)
export ORACLE_HOME=/opt/oracle/product/19c/db_home1
export ORACLE_SID=orcl_dm
export PATH=$PATH:$ORACLE_HOME/bin
S3B=DevOps/rman_backups
BACKUP=/orabkp/orabackup/ORA_DM

fullbackup() {
	rman <<EOF
connect target /
backup incremental level 0 
cumulative device type disk 
format '$BACKUP/autobackup/$DATE/full_dm_\%d_\%T.bkp'
tag 'ORA_DM' database;
backup device type disk tag 'ORA_DM'
format '$BACKUP/autobackup/$DATE/full_dm_archivelog_\%d_\%T.bkp'
archivelog all not backed up delete all input;
delete noprompt obsolete device type disk;
exit
EOF
}

pfile() {
	sqlplus / as sysdba <<EOF >"pfile_output"
	create pfile='${BACKUP}/autobackup/${DATE}/pfileorcl_dm.ora' from memory;
EOF
	if grep -q "ORA-" "pfile_output" || grep -q "SP2-" "pfile_output"; then
		return 1
	else
		return 0
	fi
}

uploadbackup() {
	check=$(aws s3api list-objects-v2 --bucket fount-data --prefix "${S3B}/${DATE}" --query 'Contents[]')
	first_string=$(echo $check | awk '{print $1}')
	echo $first_string
	[[ $first_string == 'null' ]] && {
		echo "creating prefix (folder) ${DATE}"
		aws s3api put-object --bucket fount-data --key $S3B/$DATE/
	}
	# upoad files to s3
	aws s3 cp $BACKUP/autobackup/$DATE s3://fount-data/$S3B/$DATE/ --quiet --recursive

	# tag backups/archivelogs
	for file in $(aws s3 ls s3://fount-data/$S3B/$DATE/ --recursive | awk 'NR>=1{print $4}'); do
		aws s3api put-object-tagging \
			--bucket fount-data \
			--key "${file}" \
			--tagging '{"TagSet": [{ "Key": "Name", "Value": "RMAN" }]}'
		#echo "aws s3api put-object-tagging --bucket fount-data --key ${file}"
	done
}

#MAIN
mkdir -p $BACKUP/autobackup/$DATE
pfile
exit_code=$?
echo $exit_code
fullbackup
uploadbackup
