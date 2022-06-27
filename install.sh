#!/bin/bash

usage () {
    cat <<EOH

$0 -n "full" -c "client_name" -o "ddd-ddd-ddd-ddd" [additional_options]

Required options:
    -n Node profile for deploying. Default: "basic"
       basic      - OS ans SSH hardening included only
       hardening  - OS hardening + SSH hardening +advanced hardening + Wazuh agent
       secure     - basic profile + Wazuh agent + ClamAV agent
       monitoring - basic profile + logs shipping agent + monitoring metrics
                    requires -c switch
       appliance  - basic profile + MySQL server + Aparavi AppAgent
                    requires -o switch
       full       - all featured above
                    reequires both -c and -o switches

       ############ lazy dba profile ############
       mysql_only  - basic profile + MySQL server

    -c Client name. Example "Aparavi"
    -o Aparavi parent object ID. Example: "ddd-ddd-ddd-ddd"

Additional options:
    -a Aparavi platform bind address. Default "preview.aparavi.com"
    -l Logstash address. Default: "logstash.aparavi.com"
    -m Mysql AppUser name. Default: "aparavi_app"
    -h Add advanced hardening or not (yes/no). Default: "no"
    -p Remount partitions for hardening or not (yes/no). Default: "no"

Nerds options:
    -d Install TMP dir. Default: "/tmp/debian11-install"
    -v Verbose on or off. Default: "on"
    -b Git branch to clone. Default: "main"
EOH
}

while getopts ":a:c:o:l:m:d:v:b:n:h:p:" options; do
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
        b)
            GIT_BRANCH=${OPTARG}
            ;;
        n)
	        NODE_PROFILE=${OPTARG}
	        ;;
        h)
	        HARDENING_ADVANCED_ADD=${OPTARG}
	        ;;
        p)
	        HARDENING_PARTITIONS_ADD=${OPTARG}
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

###### required switches checking ###### 
function check_c_switch {
if [[ -z "$NODE_META_SERVICE_INSTANCE" ]]; then
    echo "Error: Option '-c' is required for selected node profile."
    usage
    exit 1
fi
}

function check_o_switch {
if [[ -z "$APARAVI_PARENT_OBJECT_ID" ]]; then
    echo "Error: Option '-o' is required for selected node profile."
    usage
    exit 1
fi
}
###### end of required switches checking ###### 
NODE_ANSIBLE_SKIP_TAGS=""
[[ -z "$HARDENING_ADVANCED_ADD" ]]&&HARDENING_ADVANCED_ADD="no"
[[ "$HARDENING_ADVANCED_ADD" == "yes" ]]&&HARDENING_ADVANCED_TAG=",hardening_advanced"||$HARDENING_ADVANCED_TAG=""
[[ -z "$HARDENING_PARTITIONS_ADD" ]]&&HARDENING_PARTITIONS_ADD="no"
[[ "$HARDENING_PARTITIONS_ADD" == "yes" ]]&&HARDENING_PARTITIONS_TAG=",hardening_partitions"||$HARDENING_PARTITIONS_TAG=""
###### Node profile dictionary ######
[[ -z "$NODE_PROFILE" ]]&&NODE_PROFILE="basic"

    case "${NODE_PROFILE}" in
        basic)
            NODE_ANSIBLE_TAGS="-t os_hardening,ssh_hardening${HARDENING_ADVANCED_TAG}${HARDENING_PARTITIONS_TAG}"
            ;;
        hardening)
            NODE_ANSIBLE_TAGS="-t os_hardening,ssh_hardening,hardening_advanced,wazuh_agent${HARDENING_PARTITIONS_TAG}"
            ;;
        secure)
            NODE_ANSIBLE_TAGS="-t os_hardening,ssh_hardening,clamav_agent,wazuh_agent${HARDENING_ADVANCED_TAG}${HARDENING_PARTITIONS_TAG}"
            ;;
        monitoring)
            check_c_switch
            NODE_ANSIBLE_TAGS="-t os_hardening,ssh_hardening,logs_collection,prometheus_node_exporter${HARDENING_ADVANCED_TAG}${HARDENING_PARTITIONS_TAG}"
            ;;
        appliance)
            check_o_switch
            NODE_ANSIBLE_TAGS="-t os_hardening,ssh_hardening,mysql_server,aparavi_appagent${HARDENING_ADVANCED_TAG}${HARDENING_PARTITIONS_TAG}"
            ;;
        full)
            check_c_switch
            check_o_switch
            NODE_ANSIBLE_TAGS=""
            NODE_ANSIBLE_SKIP_TAGS="--skip-tags notag"
            [[ "$HARDENING_ADVANCED_ADD" == "yes" ]]||NODE_ANSIBLE_SKIP_TAGS="${NODE_ANSIBLE_SKIP_TAGS},hardening_advanced"
            [[ "$HARDENING_PARTITIONS_ADD" == "yes" ]]||NODE_ANSIBLE_SKIP_TAGS="${NODE_ANSIBLE_SKIP_TAGS},hardening_partitions"
            ;;
        mysql_only)
            NODE_ANSIBLE_TAGS="-t os_hardening,ssh_hardening,mysql_server${HARDENING_ADVANCED_TAG}${HARDENING_PARTITIONS_TAG}"
            ;;
        *)
	    echo "Error: please provide node profile (\"-n\" switch) from the list: basic, secure, monitoring, appliance, full, mysql_only"
            usage
            exit 1
            ;;
    esac
###### end of node profile dictionary ######

shift "$((OPTIND-1))"
if [[ $# -ge 1 ]]; then
    echo "Error: '$@' - non-option arguments. Don't use them"
    usage
    exit 1
fi

[[ "$VERBOSE_ON_OFF" == "off" ]]&&VERBOSE=""||VERBOSE="-v"

[[ -z "$APARAVI_PLATFORM_BIND_ADDR" ]]&&APARAVI_PLATFORM_BIND_ADDR="preview.aparavi.com"
[[ -z "$LOGSTASH_ADDRESS" ]]&&LOGSTASH_ADDRESS="logstash.aparavi.com"

[[ -z "$MYSQL_APPUSER_NAME" ]]&&MYSQL_APPUSER_NAME="aparavi_app"
[[ -z "$INSTALL_TMP_DIR" ]]&&INSTALL_TMP_DIR="/tmp/debian11-install"
[[ -z "$GIT_BRANCH" ]]&&GIT_BRANCH="main"

########################
### for servers without sshd service
[[ -f "/etc/ssh/ssh_host_ecdsa_key" ]]||ssh-keygen -A
[[ -d "/run/sshd" ]]||mkdir -p /run/sshd

sed -i 's/deb cdrom/#deb cdrom/' /etc/apt/sources.list
apt update
apt install ansible git sshpass vim python3-mysqldb gnupg2 -y

### Make sure target directory exists and empty
mkdir -p $INSTALL_TMP_DIR
cd $INSTALL_TMP_DIR
[ -d "./aparavi-infrastructure" ] && rm -rf ./aparavi-infrastructure

###### download all ansible stuff to the machine ######
git clone -b $GIT_BRANCH https://github.com/Aparavi-Operations/aparavi-infrastructure.git
cd aparavi-infrastructure/ansible/
export ANSIBLE_ROLES_PATH="$INSTALL_TMP_DIR/aparavi-infrastructure/ansible/roles/"
ansible-galaxy install -r roles/requirements.yml

###### run ansible ######
ansible-playbook --connection=local $INSTALL_TMP_DIR/aparavi-infrastructure/ansible/playbooks/base/main.yml -i 127.0.0.1, $VERBOSE $NODE_ANSIBLE_TAGS $NODE_ANSIBLE_SKIP_TAGS \
    --extra-vars    "mysql_appuser_name=$MYSQL_APPUSER_NAME \
                    aparavi_platform_bind_addr=$APARAVI_PLATFORM_BIND_ADDR \
                    node_meta_service_instance=$NODE_META_SERVICE_INSTANCE \
                    aparavi_parent_object=$APARAVI_PARENT_OBJECT_ID \
                    logstash_address=$LOGSTASH_ADDRESS \
                    install_tmp_dir=$INSTALL_TMP_DIR"
