#!/bin/bash

INSTALL_TMP_DIR=~

cd "$INSTALL_TMP_DIR/aparavi-infrastructure/ansible"
export ANSIBLE_ROLES_PATH="$INSTALL_TMP_DIR/aparavi-infrastructure/ansible/roles"

ansible-playbook \
  --connection=local \
  -i 127.0.0.1, \
  playbooks/base/monitoring.yml
