#!/bin/bash


[[ -z "$1" ]]&&NODE_META_SERVICE_INSTANCE="new_client1"||NODE_META_SERVICE_INSTANCE=$1
[[ -z "$2" ]]&&APARAVI_PARENT_OBJECT_ID="ddd-ddd-ddd-ddd"||APARAVI_PARENT_OBJECT_ID=$2


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


ansible-playbook --connection=local /root/aparavi-infrastructure/ansible/playbooks/base/main.yml -i 127.0.0.1, -v \
    --extra-vars "mysql_appuser_name=$MYSQL_APPUSER_NAME aparavi_parent_object=$APARAVI_PARENT_OBJECT_ID node_meta_service_instance=$NODE_META_SERVICE_INSTANCE"
