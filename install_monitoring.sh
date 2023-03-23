#!/bin/bash

INSTALL_TMP_DIR=~

cd "$INSTALL_TMP_DIR/aparavi-infrastructure/ansible"
export ANSIBLE_ROLES_PATH="$INSTALL_TMP_DIR/aparavi-infrastructure/ansible/roles"

# Install pipenv
apt install -y pipenv
pipenv install --skip-lock

pipenv run ansible-playbook \
  --connection=local \
  -i 127.0.0.1, \
  playbooks/monitoring/main.yml
