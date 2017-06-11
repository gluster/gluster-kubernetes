#!/bin/bash

ansible-playbook -e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'" -e "vagrant_home=${VAGRANT_HOME:-~/.vagrant.d}" -i .vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory $@ docker_cache.yml
