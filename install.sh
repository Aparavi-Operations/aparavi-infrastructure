#!/bin/bash

usage () {
    cat <<EOH

$0 -n "full" -c "client_name" -o "ddd-ddd-ddd-ddd" [additional_options]

Required options:
    -n Node profile for deploying. Default: "default"
       basic                             - OS and SSH hardening included only
       hardening_advanced                - OS hardening + SSH hardening + advanced hardening + Wazuh agent + ClamAV agent
       hardening_advanced_and_partitions - OS hardening + SSH hardening + advanced hardening + Wazuh agent + ClamAV agent + partitions
       monitoring                        - basic profile + logs shipping agent + monitoring metrics, requires "-c" switch
       default                           - OS hardening + SSH hardening + Wazuh agent + ClamAV agent + MySQL server + Aparavi AppAgent + logs shipping agent + monitoring metrics
       full_without_partitions           - all featured above without partitions, requires both "-c" and "-o" switches
       full                              - all featured above, requires both "-c" and "-o" switches. The most secure version of the application installation. There may be server issues
       mysql_only                        - basic profile + MySQL server

       ############ lazy dba profile ############
       mysql_only  - basic profile + MySQL server

    -c Client name. Example "Aparavi"
    -o Aparavi parent object ID. Example: "ddd-ddd-ddd-ddd"

Additional options:
    -a Aparavi platform bind address. Default "preview.aparavi.com"
    -l Logstash address. Default: "logstash.aparavi.com"
    -m Mysql AppUser name. Default: "aparavi_app"

Nerds options:
    -d Install TMP dir. Default: "/tmp/debian11-install"
    -v Verbose on or off. Default: "on"
    -b Git branch to clone. Default: "main"
    -u Aparavi app download url. Default: "https://aparavi.jfrog.io/artifactory/aparavi-installers-public/linux-installer-latest.run"
EOH
}

while getopts ":a:c:o:l:m:d:v:b:n:u:" options; do
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
        u)  
            DOWNLOAD_URL=${OPTARG}
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
###### Node profile dictionary ######
[[ -z "$NODE_PROFILE" ]]&&NODE_PROFILE="default"

    case "${NODE_PROFILE}" in
        basic)
            NODE_ANSIBLE_TAGS="-t os_hardening,ssh_hardening"
            ;;
        hardening_advanced)
            NODE_ANSIBLE_TAGS="-t os_hardening,ssh_hardening,hardening_advanced,wazuh_agent,clamav_agent"
            ;;
        hardening_advanced_and_partitions)
            NODE_ANSIBLE_TAGS="-t os_hardening,ssh_hardening,hardening_advanced,wazuh_agent,clamav_agent,hardening_partitions"
            ;;
        monitoring)
            check_c_switch
            NODE_ANSIBLE_TAGS="-t os_hardening,ssh_hardening,logs_collection,prometheus_node_exporter"
            ;;
        appliance)
            check_o_switch
            NODE_ANSIBLE_TAGS="-t os_hardening,ssh_hardening,mysql_server,aparavi_appagent"
            ;;
        default)
            check_c_switch
            check_o_switch
            NODE_ANSIBLE_TAGS="-t os_hardening,ssh_hardening,mysql_server,aparavi_appagent,clamav_agent,wazuh_agent,logs_collection,prometheus_node_exporter"
            ;;
        full_without_partitions)
            check_c_switch
            check_o_switch
            NODE_ANSIBLE_TAGS="-t os_hardening,ssh_hardening,mysql_server,aparavi_appagent,clamav_agent,wazuh_agent,logs_collection,prometheus_node_exporter,hardening_advanced"
            ;;
        full)
            check_c_switch
            check_o_switch
            NODE_ANSIBLE_TAGS=""
            ;;
        mysql_only)
            NODE_ANSIBLE_TAGS="-t os_hardening,ssh_hardening,mysql_server"
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
[[ -z "$DOWNLOAD_URL" ]]&&DOWNLOAD_URL_VAR=""||DOWNLOAD_URL_VAR="aparavi_app_url=$DOWNLOAD_URL"


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
ansible-playbook --connection=local $INSTALL_TMP_DIR/aparavi-infrastructure/ansible/playbooks/base/main.yml -i 127.0.0.1, $VERBOSE $NODE_ANSIBLE_TAGS \
    --extra-vars    "mysql_appuser_name=$MYSQL_APPUSER_NAME \
                    aparavi_platform_bind_addr=$APARAVI_PLATFORM_BIND_ADDR \
                    node_meta_service_instance=$NODE_META_SERVICE_INSTANCE \
                    aparavi_parent_object=$APARAVI_PARENT_OBJECT_ID \
                    logstash_address=$LOGSTASH_ADDRESS \
                    install_tmp_dir=$INSTALL_TMP_DIR \
                    aparavi_app_url=$DOWNLOAD_URL"
                    $DOWNLOAD_URL_VAR"
                    