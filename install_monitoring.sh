#!/bin/bash

INSTALL_TMP_DIR=~

ansible-playbook \
  --connection=local \
  -i 127.0.0.1, \
  $INSTALL_TMP_DIR/aparavi-infrastructure/ansible/playbooks/base/monitoring.yml
