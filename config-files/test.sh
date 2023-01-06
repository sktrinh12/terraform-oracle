#!/bin/bash

ORACLE_HOME="/u01/app/oracle/product/19.3/db_home"
TMP_HOME=/home/oracle
BACKUP=/orabackup/ORA_DM
ORA_DATA=/oradata/ORA_DM
S3B=DevOps/rman_backups

set -ex

# install required packages
sudo yum update -y
sudo yum install -y yum-utils oracle-database-preinstall-19c epel-release jq

# download & install aws cli
cd /tmp
curl -LJO "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
unzip awscli-exe-linux-x86_64.zip
sudo ./aws/install
eval "echo \"oracle  ALL=(ALL) NOPASSWD:ALL\" | tee \"/etc/sudoers.d/oracle\""
sudo rm awscli-exe-linux-x86_64.zip

echo "complete!"
