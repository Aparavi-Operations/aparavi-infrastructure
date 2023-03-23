#!/bin/bash

function get_local_ip() {
  for ip in $(/usr/bin/hostname -I); do
    if [[ $ip != 10.* && $ip != 172.17.* ]]; then
      echo $ip
      return
    fi
  done
}

INSTALL_TMP_DIR=~

cd "$INSTALL_TMP_DIR/aparavi-infrastructure/ansible"

export ENVIRONMENT=ohio
export SERVICE_INSTANCE=automation_test
export PLATFORM_IP="$(get_local_ip)"


export ANSIBLE_ROLES_PATH="$INSTALL_TMP_DIR/aparavi-infrastructure/ansible/roles"
export PIPENV_PIPFILE="$INSTALL_TMP_DIR/aparavi-infrastructure/Pipfile"

# Install pipenv
apt install -y pipenv
pipenv install --skip-lock

# Install docker
# pipenv run ansible-playbook \
#   --connection=local \
#   -i 127.0.0.1, \
#   playbooks/monitoring/main.yml

cd "$INSTALL_TMP_DIR/aparavi-infrastructure/monitoring"
pipenv run jinja -E ENVIRONMENT -E PLATFORM_IP vmagent/scrape.yml.j2 -o vmagent/scrape.yml
