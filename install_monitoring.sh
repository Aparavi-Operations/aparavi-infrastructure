#!/bin/bash

INSTALL_TMP_DIR=~

cd "$INSTALL_TMP_DIR/aparavi-infrastructure/ansible"

export ENVIRONMENT=ohio
export SERVICE_INSTANCE=automation_test

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
pipenv run jinja -E ENVIRONMENT vmagent/scrape.yml.j2
