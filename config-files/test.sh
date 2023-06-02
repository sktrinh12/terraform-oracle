#!/bin/bash

ORACLE_HOME="/u01/app/oracle/product/19.3/db_home"
TMP_HOME=/home/oracle
BACKUP=/orabackup/ORA_DM
ORA_DATA=/oradata/ORA_DM
S3B=DevOps/rman_backups
HOME_AWS=/home/ec2-user
IP_ADDR=$(cat $HOME_AWS/ip_addr)

set -ex

echo $1
echo $2

set -ex

# mount both ebs volumes
echo "starting ebs mount script ..."
sleep 80
mkfs -t ext4 /dev/xvdb
mkfs -t ext4 /dev/xvdc
mkdir /oradata
mkdir /orabkp
mount /dev/xvdb /oradata
echo "/dev/xvdb /oradata ext4 defaults,nofail 0 2" >>/etc/fstab
mount /dev/xvdc /orabkp
echo "/dev/xvdc /orabkp ext4 defaults,nofail 0 2" >>/etc/fstab
trap '/usr/local/bin/aws sns publish --topic-arn arn:aws:sns:us-west-2:352353521492:Tray-io-Test --message "[$IP_ADDR | $HOSTNAME] Error occurred while running the script: $BASH_COMMAND"' ERR

# install required packages
# sudo yum update -y
# sudo yum install -y oracle-database-preinstall-19c

# download & install aws cli
# cd /tmp
# curl -LJO "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
# unzip awscli-exe-linux-x86_64.zip
# sudo ./aws/install
# eval "echo \"oracle  ALL=(ALL) NOPASSWD:ALL\" | tee \"/etc/sudoers.d/oracle\""
# sudo rm awscli-exe-linux-x86_64.zip

# echo "complete!"
# /usr/local/bin/aws sns publish --topic-arn arn:aws:sns:us-west-2:352353521492:Tray-io-Test --message "[$IP_ADDR | $HOSTNAME] Sucess running script!"
