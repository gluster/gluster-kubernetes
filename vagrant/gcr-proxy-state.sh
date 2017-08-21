#!/bin/bash

if [[ "${1}" != "present" ]] && [[ "${1}" != "absent" ]]; then
  echo "Error: must supply state, either 'present' or 'absent'"
  echo "  Example: ./${0} absent"
  exit 1
fi

ansible-playbook -i /vagrant/ansible-inventory -e gcr_proxy_state="${1}" gcr_proxy.yml
