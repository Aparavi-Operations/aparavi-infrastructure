#!/bin/bash

[[ -z "$1" ]]&&APARAVI_PLATFORM_BIND_ADDR="preview.aparavi.com"||APARAVI_PLATFORM_BIND_ADDR=$1
[[ -z "$2" ]]&&NODE_META_SERVICE_INSTANCE="new_client1"||NODE_META_SERVICE_INSTANCE=$2
[[ -z "$3" ]]&&APARAVI_PARENT_OBJECT_ID="ddd-ddd-ddd-ddd"||APARAVI_PARENT_OBJECT_ID=$3
[[ -z "$4" ]]&&LOGSTASH_ADDRESS="logstash.aparavi.com"||LOGSTASH_ADDRESS=$4


MYSQL_APPUSER_NAME="aparavi_app"
INSTALL_TMP_DIR="/tmp/debian11-install"


########################

sed -i 's/deb cdrom/#deb cdrom/' /etc/apt/sources.list
apt update
apt install ansible git sshpass vim python3-mysqldb -y

### Make sure target directory exists and empty
mkdir $INSTALL_TMP_DIR
cd $INSTALL_TMP_DIR
[ -d "./aparavi-infrastructure" ] && rm -rf ./aparavi-infrastructure

cd $INSTALL_TMP_DIR
git clone https://github.com/Aparavi-Operations/aparavi-infrastructure.git
cd aparavi-infrastructure/ansible/
export ANSIBLE_ROLES_PATH="$INSTALL_TMP_DIR/aparavi-infrastructure/ansible/roles/"
ansible-galaxy install -r roles/requirements.yml


ansible-playbook --connection=local $INSTALL_TMP_DIR/aparavi-infrastructure/ansible/playbooks/base/main.yml -i 127.0.0.1, -v \
    --extra-vars "mysql_appuser_name=$MYSQL_APPUSER_NAME aparavi_platform_bind_addr=$APARAVI_PLATFORM_BIND_ADDR node_meta_service_instance=$NODE_META_SERVICE_INSTANCE aparavi_parent_object=$APARAVI_PARENT_OBJECT_ID logstash_address=$LOGSTASH_ADDRESS"
