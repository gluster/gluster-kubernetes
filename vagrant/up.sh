#!/bin/sh

# download the box(es) to prevent issues with parallel "vagrant up"
BOXES=$(awk -F '"' '/config.vm.box/ {print $2}' Vagrantfile | sort -u)
for BOX in ${BOXES}; do
  if ! (vagrant boxes list | grep -q -e "^${BOX}[[:space:]]"); then
    vagrant box add "${BOX}"
  fi
done

export ANSIBLE_TIMEOUT=60
vagrant up --no-provision "${@}" \
    && vagrant provision

if [ $? -eq 0 ] && [[ "x$(vagrant plugin list | grep sahara)" != "x" ]]; then
  vagrant sandbox on
fi
