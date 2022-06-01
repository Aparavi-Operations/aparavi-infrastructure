#!/bin/bash

usage () {
    cat <<EOH

$0  -c "client_name" -o "ddd-ddd-ddd-ddd" [additional_options]

Required options:
    -c Client name. Example "Aparavi"
    -o Aparavi parent object ID. Example: "ddd-ddd-ddd-ddd"
Additional options:
    -a Aparavi platform bind address. Default "preview.aparavi.com"
    -l Logstash address. Default: "logstash.aparavi.com"
    -m Mysql AppUser name. Default: "aparavi_app"
    -d Install TMP dir. Default: "/tmp/debian11-install"
    -v Verbose on or off. Default: "on"
EOH
}

while getopts ":a:c:o:l:m:d:v:" options; do
    case "${options}" in
        c)
            NODE_META_SERVICE_INSTANCE=${OPTARG}
            ;;
        o)
            APARAVI_PARENT_OBJECT_ID=${OPTARG}
            ;;
        a)
            APARAVI_PLATFORM_BIND_ADDR=${OPTARG}
            ;;
        l)
            LOGSTASH_ADDRESS=${OPTARG}
            ;;
        m)
            MYSQL_APPUSER_NAME=${OPTARG}
            ;;
        d)
            INSTALL_TMP_DIR=${OPTARG}
            ;;
        v)
            VERBOSE_ON_OFF=${OPTARG}
            ;;
        :)  # If expected argument omitted:
            echo "Error: -${OPTARG} requires an argument."
            usage
            exit 1
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

if [[ $OPTIND -eq 1 ]]; then
    echo "Error: No options were passed. Options '-c' and '-o' are required."
    usage
    exit 1
fi
shift "$((OPTIND-1))"
if [[ $# -ge 1 ]]; then
    echo "Error: '$@' - non-option arguments. Don't use them"
    usage
    exit 1
fi

if [[ -z "$NODE_META_SERVICE_INSTANCE" ]]; then
    echo "Error: Options '-c' and '-o' are required."
    usage
    exit 1
fi
if [[ -z "$APARAVI_PARENT_OBJECT_ID" ]]; then
    echo "Error: Options '-c' and '-o' are required."
    usage
    exit 1
fi
[[ "$VERBOSE_ON_OFF" == "off" ]]&&VERBOSE=""||VERBOSE="-v"

[[ -z "$APARAVI_PLATFORM_BIND_ADDR" ]]&&APARAVI_PLATFORM_BIND_ADDR="preview.aparavi.com"
[[ -z "$LOGSTASH_ADDRESS" ]]&&LOGSTASH_ADDRESS="logstash.aparavi.com"

[[ -z "$MYSQL_APPUSER_NAME" ]]&&MYSQL_APPUSER_NAME="aparavi_app"
[[ -z "$INSTALL_TMP_DIR" ]]&&INSTALL_TMP_DIR="/tmp/debian11-install"

########################

sed -i 's/deb cdrom/#deb cdrom/' /etc/apt/sources.list
apt update
apt install ansible git sshpass vim python3-mysqldb -y

### Make sure target directory exists and empty
mkdir $INSTALL_TMP_DIR
cd $INSTALL_TMP_DIR
[ -d "./aparavi-infrastructure" ] && rm -rf ./aparavi-infrastructure
git clone https://github.com/Aparavi-Operations/aparavi-infrastructure.git
cd aparavi-infrastructure/ansible/
export ANSIBLE_ROLES_PATH="$INSTALL_TMP_DIR/aparavi-infrastructure/ansible/roles/"
ansible-galaxy install -r roles/requirements.yml


ansible-playbook --connection=local $INSTALL_TMP_DIR/aparavi-infrastructure/ansible/playbooks/base/main.yml -i 127.0.0.1, $VERBOSE \
    --extra-vars    "mysql_appuser_name=$MYSQL_APPUSER_NAME \
                    aparavi_platform_bind_addr=$APARAVI_PLATFORM_BIND_ADDR \
                    node_meta_service_instance=$NODE_META_SERVICE_INSTANCE \
                    aparavi_parent_object=$APARAVI_PARENT_OBJECT_ID \
                    logstash_address=$LOGSTASH_ADDRESS"
